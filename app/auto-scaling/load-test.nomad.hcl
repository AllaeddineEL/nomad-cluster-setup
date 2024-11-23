### ----------------------------------------------------------------------------
###  Job Autoscaler
### ----------------------------------------------------------------------------

job "loadtest" {

  ## ---------------------------------------------------------------------------
  ##  Group Autoscaler
  ## ---------------------------------------------------------------------------

  group "loadtest" {
    count = 50
    network {
      port "http" {}
      dns {
      	servers = ["172.17.0.1"] 
      }
    }

    # --------------------------------------------------------------------------
    #  Task Autoscaler
    # --------------------------------------------------------------------------

    task "hey" {

      driver = "docker"

      config {
        image   = "ricoli/hey:latest"
        entrypoint = ["sh"]
        ports   = ["http"]
        args = ["-c", "chmod 777 /local/loadtest.sh && /local/loadtest.sh http://frontend.service.dc1.global:3000" ]
      }
      template {
        data = <<EOF
          #!/bin/sh

          # This script requires the hey tool
          # https://github.com/rakyll/hey

          [ -z "$1" ] && echo "No URL passed as first argument...exiting" && exit 1

          _URL=$1
          echo "Application address: $_URL"

          _waves=5

          _wave_duration=15
          _workers_multiplier=7
          _rate_multiplier=6
          _sleep_time=7


          for i in $(seq 1 $_waves);
          do
              _wave_duration=15
              _concurrent_workers=$(($_workers_multiplier * $i))
              _rate_limit_per_sec_per_worker=$(($_rate_multiplier * $i))

              echo "Sending $(($_wave_duration * $_concurrent_workers * $_rate_limit_per_sec_per_worker)) requests over $_wave_duration seconds"

              hey -z "$_wave_duration"s -c $_concurrent_workers -q $_rate_limit_per_sec_per_worker -m GET ${_URL} > /dev/null

              echo "Waiting $_sleep_time seconds..."
              sleep $_sleep_time
          done
        EOF

        destination = "local/loadtest.sh"
        change_mode = "noop"
      }
    }
  }
}