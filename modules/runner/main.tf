resource "azurerm_container_app_job" "runner" {
  name                         = var.job_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = var.aca_env_id
  tags                         = var.tags

  replica_timeout_in_seconds = 1800 # 30 min — covers the longest expected Terraform apply
  replica_retry_limit        = 0    # ephemeral runner: fail fast, never retry

  event_trigger_config {
    parallelism              = 1
    replica_completion_count = 1

    scale {
      min_executions              = 0  # scales to zero when no jobs are queued
      max_executions              = var.max_concurrent_runners
      polling_interval_in_seconds = 30

      rules {
        name             = "github-runner-scaler"
        custom_rule_type = "github-runner"

        # KEDA GitHub runner scaler — starts one job instance per queued workflow job
        # matching the runner labels. Requires manage_runners:org scope on the PAT.
        metadata = {
          owner                     = var.github_org
          runnerScope               = "org"
          labels                    = var.runner_labels
          targetWorkflowQueueLength = "1"
        }

        authentication {
          secret_name       = "github-pat"
          trigger_parameter = "personalAccessToken"
        }
      }
    }
  }

  template {
    container {
      name   = "runner"
      image  = "ghcr.io/actions/runner:latest"
      cpu    = var.cpu
      memory = var.memory

      # Override the default entrypoint: obtain a JIT runner token from the GitHub API
      # and start the runner in ephemeral mode. The runner deregisters automatically
      # after completing one job, keeping the runner list clean.
      command = ["/bin/bash"]
      args = [
        "-c",
        <<-EOT
          set -e
          which jq > /dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq jq)
          JIT_RESPONSE=$(curl -fsSL \
            -X POST \
            -H "Authorization: Bearer $${GITHUB_PAT}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/orgs/$${GITHUB_ORG}/actions/runners/generate-jitconfig" \
            -d "{\"name\":\"azure-$(hostname)-$(date +%s)\",\"runner_group_id\":1,\"labels\":[\"self-hosted\",\"azure\",\"$${ENVIRONMENT}\"],\"work_folder\":\"_work\"}")
          JIT_CONFIG=$(echo "$${JIT_RESPONSE}" | jq -r '.encoded_jit_config')
          cd /home/runner
          exec ./run.sh --jitconfig "$${JIT_CONFIG}"
        EOT
      ]

      env {
        name        = "GITHUB_PAT"
        secret_name = "github-pat"
      }

      env {
        name  = "GITHUB_ORG"
        value = var.github_org
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    }
  }

  secret {
    name  = "github-pat"
    value = var.runner_pat
  }
}
