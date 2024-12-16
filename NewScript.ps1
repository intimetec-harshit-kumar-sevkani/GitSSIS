# Import the required assembly for SSIS runtime
Add-Type -Path "$PSScriptRoot\lib\Microsoft.SQLServer.ManagedDTS.dll"

param (
    [string]$projectDirectory = "$PSScriptRoot\Integration Services Project3"
)

function Check-SSISConnectionManagers {
    param (
        [string]$projectDirectory
    )

    # Get all .dtsx files in the project directory
    $dtsxFiles = Get-ChildItem -Path $projectDirectory -Recurse -Filter "*.dtsx"

    foreach ($file in $dtsxFiles) {
        Write-Host "Processing package: $($file.FullName)"

        # Load the SSIS package
        $app = New-Object Microsoft.SqlServer.Dts.Runtime.Application
        $package = $app.LoadPackage($file.FullName, $null)

        foreach ($connectionManager in $package.Connections) {
            $connectionManagerName = $connectionManager.Name
            Write-Host "Checking Connection Manager: $connectionManagerName"

            # Check the HasExpressions property
            $hasExpressions = $connectionManager.HasExpressions
            Write-Host "HasExpressions for Connection Manager '$connectionManagerName': $hasExpressions"

            if ($hasExpressions) {
                # Fetch Connection String Expression
                $connectionStringExpression = $connectionManager.GetExpression("ConnectionString")
                Write-Host "Raw ConnectionString Expression: $connectionStringExpression"

                # Extract Initial Catalog and Server Name explicitly
                $initialCatalog = $null
                $serverName = $null

                try {
                    $initialCatalog = $connectionManager.Properties["InitialCatalog"].GetValue($connectionManager)
                    Write-Host "Initial Catalog: $initialCatalog"
                } catch {
                    Write-Host "Initial Catalog property is not available."
                }

                try {
                    $serverName = $connectionManager.Properties["ServerName"].GetValue($connectionManager)
                    Write-Host "Server Name: $serverName"
                } catch {
                    Write-Host "Server Name property is not available."
                }

                # Construct connection string for testing
                if ($initialCatalog -and $serverName) {
                    $testConnectionString = "Data Source=$serverName;Initial Catalog=$initialCatalog;Integrated Security=True;"
                    Write-Host "Constructed Test Connection String: $testConnectionString"

                    # Test connection
                    try {
                        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
                        $sqlConnection.ConnectionString = $testConnectionString
                        $sqlConnection.Open()
                        Write-Host "Connection to '$connectionManagerName' successful."
                        $sqlConnection.Close()
                    } catch {
                        Write-Error "Failed to connect using connection manager '$connectionManagerName': $_"
                    }
                } else {
                    Write-Error "Cannot construct a valid connection string due to missing Initial Catalog or Server Name."
                }
            } else {
                Write-Host "Connection Manager '$connectionManagerName' does not have an expression for its ConnectionString."
            }
        }
    }
}

# Check connection managers for all packages in the project
Check-SSISConnectionManagers -projectDirectory $projectDirectory

