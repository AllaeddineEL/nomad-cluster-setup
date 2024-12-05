Kind = "http-route"
Name = "nginb-route"

// Rules define how requests will be routed
Rules = [
  {
    Matches = [
      {
        Path = {
          Match = "prefix"
          Value = "/hashicups"
        }
      }
    ]
    Services = [
      {
        Name = "nginx"
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