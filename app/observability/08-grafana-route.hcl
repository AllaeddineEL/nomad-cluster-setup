Kind = "http-route"
Name = "grafana-route"

// Rules define how requests will be routed
Rules = [
  {
    Matches = [
      {
        Path = {
          Match = "prefix"
          Value = "/grafana"
        }
      }
    ]
    Services = [
      {
        Name = "grafana"
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