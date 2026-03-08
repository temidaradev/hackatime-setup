use std::path::PathBuf;

use color_eyre::{Result, eyre::eyre};

use super::EditorPlugin;

const DOWNLOAD_URL: &str =
    "https://github.com/wakatime/macos-wakatime/releases/latest/download/macos-wakatime.zip";

pub struct Xcode;

impl Xcode {
    fn app_path() -> PathBuf {
        PathBuf::from("/Applications/WakaTime.app")
    }
}

impl EditorPlugin for Xcode {
    fn name(&self) -> String {
        "Xcode".to_string()
    }

    fn is_installed(&self) -> bool {
        #[cfg(target_os = "macos")]
        {
            PathBuf::from("/Applications/Xcode.app").exists()
                || std::process::Command::new("xcrun")
                    .arg("--version")
                    .output()
                    .is_ok_and(|o| o.status.success())
        }

        #[cfg(not(target_os = "macos"))]
        {
            false
        }
    }

    fn install(&self) -> Result<Option<String>> {
        #[cfg(not(target_os = "macos"))]
        {
            return Err(eyre!("Xcode is only supported on macOS"));
        }

        #[cfg(target_os = "macos")]
        {
            use std::fs;
            use std::process::Command;

            if Self::app_path().exists() {
                return Ok(None);
            }

            let tmp_dir =
                tempfile::tempdir().map_err(|e| eyre!("Failed to create temp directory: {}", e))?;
            let zip_path = tmp_dir.path().join("macos-wakatime.zip");

            let client = reqwest::blocking::Client::new();
            let response = client
                .get(DOWNLOAD_URL)
                .send()
                .map_err(|e| eyre!("Failed to download WakaTime for Mac: {}", e))?;

            if !response.status().is_success() {
                return Err(eyre!(
                    "Failed to download WakaTime for Mac (HTTP {})",
                    response.status()
                ));
            }

            let bytes = response
                .bytes()
                .map_err(|e| eyre!("Failed to read download: {}", e))?;
            fs::write(&zip_path, &bytes).map_err(|e| eyre!("Failed to write zip file: {}", e))?;

            let status = Command::new("ditto")
                .args([
                    "-xk",
                    &zip_path.to_string_lossy(),
                    &tmp_dir.path().to_string_lossy(),
                ])
                .output()
                .map_err(|e| eyre!("Failed to unzip: {}", e))?;

            if !status.status.success() {
                return Err(eyre!(
                    "Failed to unzip WakaTime.app: {}",
                    String::from_utf8_lossy(&status.stderr)
                ));
            }

            let extracted_app = tmp_dir.path().join("WakaTime.app");
            if !extracted_app.exists() {
                return Err(eyre!("WakaTime.app not found in downloaded archive"));
            }

            let status = Command::new("cp")
                .args([
                    "-R",
                    &extracted_app.to_string_lossy(),
                    &Self::app_path().to_string_lossy(),
                ])
                .output()
                .map_err(|e| eyre!("Failed to move WakaTime.app to /Applications: {}", e))?;

            if !status.status.success() {
                return Err(eyre!(
                    "Failed to copy WakaTime.app to /Applications: {}",
                    String::from_utf8_lossy(&status.stderr)
                ));
            }

            Command::new("open")
                .arg(Self::app_path())
                .spawn()
                .map_err(|e| eyre!("Failed to launch WakaTime.app: {}", e))?;

            Ok(None)
        }
    }
}
