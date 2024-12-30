Kind = "service-intentions"
Name = "prometheus-server"
Sources = [
  {
    Name   = "api-gateway"
    Action = "allow"
  },
  {
    Name   = "grafana"
    Action = "allow"
  },
  {
    Name   = "consul"
    Action = "allow"
  }
]