      env {
        APP_ENV                 = "staging"
        DEMO_MODE               = "true"
        SITE_PHASE              = "live"
        NODE_ENV                = "production"
        PUBLIC_ORIGIN           = "https://backoffice-demo.sacha.house"
        DATABASE_PATH           = "/var/lib/backoffice-demo/froment.sqlite"
        ENTERPRISE_NAME         = "ACME"
        TRUSTED_PROXY_ADDRESSES = "172.18.0.1"
      }

      template {
        data = <<EOH
{{ with nomadVar "nomad/jobs/backoffice-demo" }}
{{ range $key, $value := . }}{{ $key }}={{ $value | toJSON }}
{{ end }}{{ end }}
EOH
        destination          = "secrets/runtime.env"
        env                  = true
        error_on_missing_key = true
        change_mode          = "restart"
      }
