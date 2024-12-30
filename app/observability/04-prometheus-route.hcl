Kind = "http-route"
Name = "prometheus-server-route"

// Rules define how requests will be routed
Rules = [
  {
    Matches = [
      {
        Path = {
          Match = "prefix"
          Value = "/prometheus"
        }
      }
    ]
    Services = [
      {
        Name = "prometheus-server"
      }
      Filters = {
        URLRewrite = {
          Path = "/"
        }
      }
    ]
  }
]

Parents = [
  {
    Kind        = "api-gateway"
    Name        = "api-gateway"
    SectionName = "hashicups-http-route"
  }
]