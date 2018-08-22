# Deploying a minimal go application onto Kubernetes using Docker Desktop and Terraform

## Prerequisites

- [The Go Programming Language](https://golang.org/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Docker Hub Account](https://hub.docker.com/)
- [HashiCorp Terraform](https://www.terraform.io/downloads.html)

## Create Test App

Using sample http app in [go](https://golang.org/) that responds with "Hello, World" to request received on port 8080:

Using your favorite editor create a file named *main.go* with the following code:

``` golang
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		fmt.Fprint(writer, "Hello, World")
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

Compile the application:

``` bash
go run main.go
```

Test the app works as expected by navigating to http://localhost:8080/ in your browser where you should see 'Hello, World' displayed.

## Create Docker Image

Using your favorite editor create a multi-stage Dockerfile named *Dockerfile* with the following code:

``` Dockerfile
FROM golang:alpine as builder
RUN mkdir /build
ADD . /build/
WORKDIR /build
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main .
FROM scratch
COPY --from=builder /build/main /app/
WORKDIR /app
ENV PORT 8080
EXPOSE 8080
ENTRYPOINT ["./main"]
```

Build a minimal docker image:

``` bash
docker build -t docker-test .
docker image ls | grep docker-test
```

Test the image using docker:

``` bash
docker run -d -p 8080:8080 docker-test
docker ps | grep docker-test
curl http://localhost:8080
docker container stop <CONTAINER-ID>
```

Tag the image and push to Docker Hub:

``` bash
docker tag docker-test <DOCKERHUB-ACCOUNT>/docker-test
docker push <DOCKERHUB-ACCOUNT>/docker-test
```

## Use Terraform to Deploy to Kubernetes

Using your favorite editor create a file named *app.tf* with the following code:

``` hcl
provider "kubernetes" {}

resource "kubernetes_namespace" "docker-test" {
  metadata {
    name = "test"
  }
}

resource "kubernetes_replication_controller" "docker-test" {
  metadata {
    name = "docker-test"
    namespace = "test"
    labels {
      App = "DockerTest"
    }
  }

  spec {
    replicas = 2
    selector {
      App = "DockerTest"
    }
    template {
      container {
        image = "<DOCKERHUB-ACCOUNT>/docker-test"
        name  = "docker-test"

        port {
          container_port = 8080
        }

        resources {
          limits {
            cpu    = "0.5"
            memory = "512Mi"
          }
          requests {
            cpu    = "250m"
            memory = "50Mi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "docker-test" {
  metadata {
    name = "docker-test"
    namespace = "test"
  }
  spec {
    selector {
      App = "${kubernetes_replication_controller.docker-test.metadata.0.labels.App}"
    }
    port {
      port = 8000
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

```

Initialize Terraform providers:

``` bash
terraform init
```

Use terraform to deploy our service to Kubernetes:

``` bash
terraform apply
```

Type 'yes' to confirm.

## Validate Deployment

### Using Command Line

Use kubectl to check deployment:

``` bash
kubectl get pods --namespace test
```

### Using Kubernetes Dashboard

Deploy the Kubernetes dashboard using the following command:

``` bash
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
```

Use the kubectl command line proxy to access the dashboard:

``` bash
kubectl proxy
```

The Kubernetes dashboard should now be available at:
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

### Using curl

Test the deployed service using curl:

``` bash
curl http://localhost:8000
```

## Clean Up

Use Terraform to teardown the environment:

``` bash
terraform destroy
```

Type 'yes' to confirm.


## References

- [Containerize This! How to build Golang Dockerfiles](https://www.cloudreach.com/blog/containerize-this-golang-dockerfiles/)
- [Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Terraform Kubernetes Provider](https://www.terraform.io/docs/providers/kubernetes/index.html)