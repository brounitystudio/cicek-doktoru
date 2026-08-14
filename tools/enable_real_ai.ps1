param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectId
)

$ErrorActionPreference = "Stop"

$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath;C:\Users\omerc\AppData\Local\Pub\Cache\bin"

Write-Host "Checking Firebase login..."
firebase login:list

Write-Host "Configuring FlutterFire for project $ProjectId..."
flutterfire configure --project=$ProjectId --platforms=android,ios,web --out=lib/firebase_options.dart --yes

Write-Host "Setting Firebase project..."
firebase use $ProjectId

Write-Host "Enter Gemini API key. It will be stored as a Firebase Functions secret, not in Flutter."
$secureKey = Read-Host "GEMINI_API_KEY" -AsSecureString
$plainKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
)

try {
  $plainKey | firebase functions:secrets:set GEMINI_API_KEY --project $ProjectId
}
finally {
  $plainKey = $null
}

Push-Location functions
try {
  Write-Host "Installing Functions dependencies..."
  npm.cmd install

  Write-Host "Building Functions..."
  npm.cmd run build
}
finally {
  Pop-Location
}

Write-Host "Deploying Cloud Functions..."
firebase deploy --only functions --project $ProjectId

Write-Host "Running Flutter checks..."
flutter analyze
flutter test

Write-Host "Done. Real AI mode is ready. Run the app without USE_MOCK_DIAGNOSIS."
