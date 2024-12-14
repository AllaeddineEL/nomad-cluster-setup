Kind = "service-intentions"
Name = "public-api"
Sources = [
  {
    Name   = "frontend"
    Action = "allow"
  },
  {
    Name   = "api-gateway"
    Action = "allow"
  }
]