// Shared Library: k8sDeploy
// Reusable function for deploying to Kubernetes
// Usage: k8sDeploy(namespace: 'production', deployment: 'myapp', image: 'myapp:v1.0', replicas: 3)

def call(Map config = [:]) {
    def namespace = config.namespace ?: 'default'
    def deploymentName = config.deployment ?: env.JOB_BASE_NAME
    def image = config.image ?: env.DOCKER_IMAGE
    def replicas = config.replicas ?: 3
    def port = config.port ?: 8080
    def servicePort = config.servicePort ?: 80
    def manifestsPath = config.manifestsPath ?: ''
    def helmChart = config.helmChart ?: ''
    def waitTimeout = config.waitTimeout ?: '5m'

    echo "Deploying to Kubernetes..."
    echo "Namespace: ${namespace}"
    echo "Deployment: ${deploymentName}"
    echo "Image: ${image}"

    stage("Deploy to ${namespace}") {
        script {
            container('kubectl') {
                // Configure kubectl
                sh 'kubectl version --client'
                sh 'kubectl config use-context homelab || true'
                sh 'kubectl get nodes'

                if (helmChart) {
                    // Deploy with Helm
                    deployWithHelm(helmChart, deploymentName, namespace, image)
                } else if (manifestsPath) {
                    // Deploy with kubectl apply
                    deployWithManifests(manifestsPath, namespace, waitTimeout)
                } else {
                    // Deploy with kubectl commands (simple deployment)
                    deploySimple(deploymentName, namespace, image, replicas, port, servicePort, waitTimeout)
                }

                // Verify deployment
                echo "Verifying deployment..."
                sh "kubectl get pods -n ${namespace} -l app=${deploymentName}"
                sh "kubectl get svc -n ${namespace} -l app=${deploymentName} || true"
            }
        }
    }
}

def deploySimple(String deploymentName, String namespace, String image, Integer replicas, Integer port, Integer servicePort, String timeout) {
    echo "Deploying with kubectl set image..."

    // Check if deployment exists
    def deploymentExists = sh(
        script: "kubectl get deployment ${deploymentName} -n ${namespace} > /dev/null 2>&1",
        returnStatus: true
    ) == 0

    if (deploymentExists) {
        echo "Updating existing deployment..."
        sh """
            kubectl set image deployment/${deploymentName} \\
                ${deploymentName}=${image} \\
                -n ${namespace}
        """
        sh """
            kubectl rollout status deployment/${deploymentName} \\
                -n ${namespace} \\
                --timeout=${timeout}
        """
    } else {
        echo "Creating new deployment..."
        sh """
            kubectl create deployment ${deploymentName} \\
                --image=${image} \\
                --replicas=${replicas} \\
                -n ${namespace}
        """
        sh """
            kubectl expose deployment ${deploymentName} \\
                --port=${servicePort} \\
                --target-port=${port} \\
                -n ${namespace} || true
        """
        sh """
            kubectl rollout status deployment/${deploymentName} \\
                -n ${namespace} \\
                --timeout=${timeout}
        """
    }
}

def deployWithHelm(String chartPath, String releaseName, String namespace, String image) {
    container('helm') {
        echo "Deploying with Helm..."
        sh 'helm version'

        def imageRepo = image.split(':')[0]
        def imageTag = image.split(':')[1]

        sh """
            helm upgrade --install ${releaseName} ${chartPath} \\
                --namespace ${namespace} \\
                --create-namespace \\
                --set image.repository=${imageRepo} \\
                --set image.tag=${imageTag} \\
                --wait \\
                --timeout 5m
        """
        sh "helm list -n ${namespace}"
    }
}

def deployWithManifests(String manifestsPath, String namespace, String timeout) {
    echo "Deploying with kubectl apply..."
    sh """
        kubectl apply -f ${manifestsPath}/ -n ${namespace}
    """

    // Wait for all deployments to roll out
    sh """
        for deployment in \$(kubectl get deployments -n ${namespace} -o name); do
            kubectl rollout status \$deployment -n ${namespace} --timeout=${timeout}
        done
    """
}

// Helper function for review app deployment
def deployReview(Map config = [:]) {
    def mrId = env.CHANGE_ID ?: 'review'
    def namespace = "review-${mrId}"
    def deploymentName = "${config.deployment ?: env.JOB_BASE_NAME}-review-${mrId}"

    echo "Creating review environment: ${namespace}"

    container('kubectl') {
        // Create namespace
        sh """
            kubectl create namespace ${namespace} || true
            kubectl label namespace ${namespace} environment=review || true
        """
    }

    // Deploy to review namespace
    config.namespace = namespace
    config.deployment = deploymentName
    config.replicas = 1
    call(config)
}

// Helper function for stopping/cleaning up environments
def cleanup(String namespace, String deploymentName = '') {
    echo "Cleaning up environment: ${namespace}"

    stage('Cleanup Environment') {
        script {
            container('kubectl') {
                if (deploymentName) {
                    sh "kubectl delete deployment ${deploymentName} -n ${namespace} || true"
                    sh "kubectl delete svc ${deploymentName} -n ${namespace} || true"
                } else {
                    sh "kubectl delete namespace ${namespace} || true"
                }
            }
        }
    }
}

// Helper function for canary deployment
def deployCanary(Map config = [:]) {
    def namespace = config.namespace ?: 'production'
    def deploymentName = "${config.deployment ?: env.JOB_BASE_NAME}-canary"
    def image = config.image ?: env.DOCKER_IMAGE
    def replicas = 1

    echo "Deploying canary version..."

    container('kubectl') {
        sh """
            kubectl create deployment ${deploymentName} \\
                --image=${image} \\
                --replicas=${replicas} \\
                -n ${namespace} || kubectl set image deployment/${deploymentName} ${deploymentName}=${image} -n ${namespace}
        """
        sh """
            kubectl label deployment ${deploymentName} version=canary -n ${namespace} --overwrite
        """
        sh """
            kubectl rollout status deployment/${deploymentName} -n ${namespace}
        """
    }

    echo "Canary deployment complete"
}
