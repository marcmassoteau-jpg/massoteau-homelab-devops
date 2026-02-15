// Shared Library: buildApp
// Reusable function for building applications with language-specific configurations
// Usage: buildApp(type: 'node', buildCommand: 'npm ci && npm run build', outputDir: 'dist')

def call(Map config = [:]) {
    def buildType = config.type ?: 'generic'
    def buildCommand = config.buildCommand ?: 'echo "No build command specified"'
    def outputDir = config.outputDir ?: 'dist'
    def cacheDir = config.cacheDir ?: ''

    echo "Starting build process..."
    echo "Build type: ${buildType}"
    echo "Build command: ${buildCommand}"

    // Language-specific configurations
    def containerImage = getContainerImage(buildType, config.version)
    def cacheKey = "${env.BRANCH_NAME}-${buildType}"
    def cachePaths = getCachePaths(buildType)

    container(buildType) {
        stage('Build Application') {
            script {
                // Setup environment
                if (buildType == 'node') {
                    sh '''
                        node --version
                        npm --version
                    '''
                } else if (buildType == 'python') {
                    sh '''
                        python --version
                        pip --version
                    '''
                } else if (buildType == 'go') {
                    sh '''
                        go version
                    '''
                }

                // Execute build command
                sh buildCommand

                echo "Build complete!"

                // Archive artifacts
                if (fileExists(outputDir)) {
                    stash(
                        name: 'build-artifacts',
                        includes: "${outputDir}/**/*"
                    )
                    archiveArtifacts(
                        artifacts: "${outputDir}/**/*",
                        allowEmptyArchive: false,
                        fingerprint: true
                    )
                    echo "Artifacts archived from ${outputDir}"
                }
            }
        }
    }
}

def getContainerImage(String type, String version = null) {
    def images = [
        'node': version ? "node:${version}-alpine" : 'node:18-alpine',
        'python': version ? "python:${version}-alpine" : 'python:3.11-alpine',
        'go': version ? "golang:${version}-alpine" : 'golang:1.21-alpine',
        'generic': 'alpine:latest'
    ]
    return images[type] ?: images['generic']
}

def getCachePaths(String type) {
    def paths = [
        'node': ['node_modules/', '.npm/'],
        'python': ['.pip-cache/', 'venv/'],
        'go': ['.go-cache/'],
        'generic': []
    ]
    return paths[type] ?: paths['generic']
}
