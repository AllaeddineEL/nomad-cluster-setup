Kind = "service-intentions"
Name = "product-api-db"
Sources = [
  {
    Name   = "vault"
    Action = "allow"
  },
  {
    Name   = "api-gateway"
    Action = "allow"
  }
]