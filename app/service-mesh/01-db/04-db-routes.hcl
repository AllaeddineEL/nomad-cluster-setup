Kind = "tcp-route"
Name = "product-db-route"

// Rules define how requests will be routed

Services = [
  {
    Name = "product-api-db"
  }
]

Parents = [
  {
    Kind        = "api-gateway"
    Name        = "hashicups-gateway"
    SectionName = "hashicups-db-tcp-route"
  }
]