Kind = "service-intentions"
Name = "grafana"
Sources = [
  {
    Name   = "api-gateway"
    Action = "allow"
  },
  {
    Name   = "consul"
    Action = "allow"
  }
]