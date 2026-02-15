// Shared Library: dockerBuild
// Reusable function for building Docker images with Kaniko
// Usage: dockerBuild(dockerfile: 'Dockerfile', imageName: 'myapp', imageTag: env.GIT_COMMIT)

def call(Map config = [:]) {
    def dockerfile = config.dockerfile ?: 'Dockerfile'
    def context = config.context ?: '.'
    def imageName = config.imageName ?: env.REGISTRY_IMAGE
    def imageTag = config.imageTag ?: env.GIT_COMMIT
    def additionalTags = config.additionalTags ?: []
    def buildArgs = config.buildArgs ?: [:]
    def cacheEnabled = config.cache ?: true
    def registry = config.registry ?: env.CI_REGISTRY ?: 'registry.gitlab.homelab.local'

    echo "Building Docker image with Kaniko..."
    echo "Dockerfile: ${dockerfile}"
    echo "Image: ${imageName}:${imageTag}"

    stage('Build Docker Image') {
        script {
            container('kaniko') {
                // Prepare Kaniko config with registry credentials
                sh """
                    mkdir -p /kaniko/.docker
                    cat > /kaniko/.docker/config.json <<EOF
{
  "auths": {
    "${registry}": {
      "username": "\${REGISTRY_USER}",
      "password": "\${REGISTRY_PASSWORD}"
    }
  }
}
EOF
                """

                // Build destination arguments
                def destinations = ["--destination=${imageName}:${imageTag}"]

                // Add additional tags
                if (additionalTags) {
                    additionalTags.each { tag ->
                        destinations.add("--destination=${imageName}:${tag}")
                    }
                } else {
                    // Default additional tag based on branch
                    destinations.add("--destination=${imageName}:${env.BRANCH_NAME}")
                }

                // Build build-arg arguments
                def buildArgsList = []
                buildArgs.each { key, value ->
                    buildArgsList.add("--build-arg ${key}=${value}")
                }

                // Construct Kaniko command
                def kanikoCmd = """
                    /kaniko/executor \\
                        --context=${context} \\
                        --dockerfile=${context}/${dockerfile} \\
                        ${destinations.join(' \\\n                        ')} \\
                        --cache=${cacheEnabled} \\
                        --cache-ttl=24h \\
                        --compressed-caching=false \\
                        --snapshot-mode=redo \\
                        ${buildArgsList.join(' \\\n                        ')} \\
                        --cleanup
                """

                // Execute build
                sh kanikoCmd

                echo "Docker image built successfully"
                echo "Image: ${imageName}:${imageTag}"

                // Set environment variable for downstream jobs
                env.DOCKER_IMAGE = "${imageName}:${imageTag}"
            }
        }
    }
}

// Helper function for multi-stage builds with custom targets
def buildStage(Map config = [:]) {
    def target = config.target ?: ''
    def dockerfile = config.dockerfile ?: 'Dockerfile'
    def context = config.context ?: '.'
    def imageName = config.imageName ?: env.REGISTRY_IMAGE
    def imageTag = config.imageTag ?: env.GIT_COMMIT

    echo "Building Docker image stage: ${target}"

    container('kaniko') {
        sh """
            /kaniko/executor \\
                --context=${context} \\
                --dockerfile=${context}/${dockerfile} \\
                --target=${target} \\
                --destination=${imageName}:${imageTag}-${target} \\
                --cache=true \\
                --cleanup
        """
    }
}

// Helper function for building with latest tag
def buildLatest(Map config = [:]) {
    if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
        config.additionalTags = config.additionalTags ?: []
        config.additionalTags.add('latest')
        call(config)
    } else {
        echo "Skipping latest tag (not on main/master branch)"
        call(config)
    }
}
