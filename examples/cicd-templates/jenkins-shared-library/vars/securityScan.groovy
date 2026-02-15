// Shared Library: securityScan
// Reusable function for security scanning
// Usage: securityScan(type: 'trivy-image', severity: 'HIGH,CRITICAL', image: 'myapp:latest')

def call(Map config = [:]) {
    def scanType = config.type ?: 'trivy-fs'
    def severity = config.severity ?: 'HIGH,CRITICAL'
    def allowFailure = config.allowFailure ?: true
    def image = config.image ?: ''
    def target = config.target ?: '.'

    echo "Starting security scan..."
    echo "Scan type: ${scanType}"
    echo "Severity: ${severity}"

    stage("Security Scan: ${scanType}") {
        script {
            try {
                switch(scanType) {
                    case 'trivy-image':
                        scanTrivyImage(image, severity)
                        break
                    case 'trivy-fs':
                        scanTrivyFilesystem(target, severity)
                        break
                    case 'secrets':
                        scanSecrets(target)
                        break
                    case 'dependencies':
                        scanDependencies(config)
                        break
                    case 'sast':
                        scanSAST(target)
                        break
                    default:
                        error("Unknown scan type: ${scanType}")
                }
            } catch (Exception e) {
                echo "Security scan failed: ${e.message}"
                if (!allowFailure) {
                    error("Security scan failed and allowFailure is false")
                } else {
                    currentBuild.result = 'UNSTABLE'
                    echo "Continuing despite scan failure (allowFailure: true)"
                }
            }
        }
    }
}

def scanTrivyImage(String image, String severity) {
    container('trivy') {
        echo "Scanning container image: ${image}"
        sh """
            trivy image \
                --severity ${severity} \
                --exit-code 0 \
                --no-progress \
                --format table \
                ${image}
        """
        sh """
            trivy image \
                --severity ${severity} \
                --exit-code 0 \
                --no-progress \
                --format json \
                --output trivy-report.json \
                ${image}
        """
        archiveArtifacts(
            artifacts: 'trivy-report.json',
            allowEmptyArchive: false,
            fingerprint: true
        )
        echo "Container image scan complete"
    }
}

def scanTrivyFilesystem(String target, String severity) {
    container('trivy') {
        echo "Scanning filesystem: ${target}"
        sh """
            trivy fs \
                --severity ${severity} \
                --exit-code 0 \
                --no-progress \
                --format table \
                ${target}
        """
        sh """
            trivy fs \
                --severity ${severity} \
                --exit-code 0 \
                --no-progress \
                --format json \
                --output trivy-fs-report.json \
                ${target}
        """
        archiveArtifacts(
            artifacts: 'trivy-fs-report.json',
            allowEmptyArchive: false,
            fingerprint: true
        )
        echo "Filesystem scan complete"
    }
}

def scanSecrets(String target) {
    container('trivy') {
        echo "Scanning for secrets in: ${target}"
        sh """
            trivy fs \
                --scanners secret \
                --exit-code 0 \
                --no-progress \
                --format table \
                ${target}
        """
        echo "Secret scan complete"
    }
}

def scanDependencies(Map config) {
    def language = config.language ?: 'node'

    echo "Scanning dependencies for ${language} project"

    if (language == 'node') {
        container('node') {
            sh '''
                npm ci
                npm audit --audit-level=high --json > npm-audit.json || true
                npm audit --audit-level=high || true
            '''
            archiveArtifacts(
                artifacts: 'npm-audit.json',
                allowEmptyArchive: true,
                fingerprint: true
            )
        }
    } else if (language == 'python') {
        container('python') {
            sh '''
                pip install safety
                pip install -r requirements.txt
                safety check --json > safety-report.json || true
                safety check || true
            '''
            archiveArtifacts(
                artifacts: 'safety-report.json',
                allowEmptyArchive: true,
                fingerprint: true
            )
        }
    } else if (language == 'go') {
        container('go') {
            sh '''
                go install golang.org/x/vuln/cmd/govulncheck@latest
                govulncheck ./... | tee govulncheck-report.txt || true
            '''
            archiveArtifacts(
                artifacts: 'govulncheck-report.txt',
                allowEmptyArchive: true,
                fingerprint: true
            )
        }
    }

    echo "Dependency scan complete"
}

def scanSAST(String target) {
    container('semgrep') {
        echo "Running SAST analysis on: ${target}"
        sh """
            semgrep --config=auto --json --output=sast-report.json ${target} || true
            semgrep --config=auto ${target} || true
        """
        archiveArtifacts(
            artifacts: 'sast-report.json',
            allowEmptyArchive: true,
            fingerprint: true
        )
        echo "SAST analysis complete"
    }
}
