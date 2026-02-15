// Shared Library: testApp
// Reusable function for running application tests
// Usage: testApp(type: 'node', testCommand: 'npm test', coverage: true)

def call(Map config = [:]) {
    def testType = config.type ?: 'generic'
    def testCommand = config.testCommand ?: 'echo "No test command specified"'
    def coverage = config.coverage ?: true
    def coverageThreshold = config.coverageThreshold ?: 80
    def services = config.services ?: []

    echo "Starting test execution..."
    echo "Test type: ${testType}"
    echo "Test command: ${testCommand}"

    container(testType) {
        stage('Run Tests') {
            script {
                // Setup environment
                if (testType == 'node') {
                    sh '''
                        node --version
                        npm --version
                    '''
                } else if (testType == 'python') {
                    sh '''
                        python --version
                        pip --version
                    '''
                } else if (testType == 'go') {
                    sh '''
                        go version
                    '''
                }

                // Execute test command
                try {
                    sh testCommand
                    echo "Tests complete!"
                } catch (Exception e) {
                    echo "Tests failed: ${e.message}"
                    currentBuild.result = 'UNSTABLE'
                    error("Test execution failed")
                }

                // Publish test results
                publishTestResults(testType)

                // Publish coverage reports
                if (coverage) {
                    publishCoverage(testType, coverageThreshold)
                }
            }
        }
    }
}

def publishTestResults(String type) {
    def testResultsFiles = [
        'node': 'test-results.xml',
        'python': 'test-results.xml',
        'go': 'test-results.xml',
        'generic': 'test-results.xml'
    ]

    def resultsFile = testResultsFiles[type] ?: testResultsFiles['generic']

    if (fileExists(resultsFile)) {
        junit(
            testResults: resultsFile,
            allowEmptyResults: false,
            skipPublishingChecks: false
        )
        echo "Test results published from ${resultsFile}"
    } else {
        echo "No test results file found at ${resultsFile}"
    }
}

def publishCoverage(String type, Integer threshold) {
    def coverageFiles = [
        'node': 'coverage/cobertura-coverage.xml',
        'python': 'coverage.xml',
        'go': 'coverage.xml',
        'generic': 'coverage.xml'
    ]

    def coverageFile = coverageFiles[type] ?: coverageFiles['generic']

    if (fileExists(coverageFile)) {
        // Archive coverage artifacts
        archiveArtifacts(
            artifacts: 'coverage/**/*',
            allowEmptyArchive: true,
            fingerprint: true
        )

        // Publish coverage report
        publishHTML(target: [
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'coverage',
            reportFiles: 'index.html',
            reportName: 'Coverage Report'
        ])

        echo "Coverage report published from ${coverageFile}"
        echo "Coverage threshold: ${threshold}%"
    } else {
        echo "No coverage file found at ${coverageFile}"
    }
}
