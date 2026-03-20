group "default" {
  targets = ["cu128", "cu130"]
}

target "cu128" {
  dockerfile = "Dockerfile"
  tags       = [
    "runpod/unsloth-studio:latest",
    "runpod/unsloth-studio:cu128"
  ]
  args = {
    CUDA_VERSION  = "cu1281"
    TORCH_BACKEND = "cu128"
  }
  platforms = ["linux/amd64"]
}

target "cu130" {
  dockerfile = "Dockerfile"
  tags       = [
    "runpod/unsloth-studio:cu130"
  ]
  args = {
    CUDA_VERSION  = "cu1300"
    TORCH_BACKEND = "cu130"
  }
  platforms = ["linux/amd64"]
}
