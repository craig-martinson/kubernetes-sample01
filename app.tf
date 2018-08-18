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
        image = "craigmartinson/docker-test"
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
