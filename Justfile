dev:
  docker build -t fly-mobileclip-dev . && docker run --rm -it -p 8000:8000 fly-mobileclip-dev