FROM golang:1.6.1

# Copy the local package files to the container's workspace.
ADD . /go/src/tmp/hello-go-ecs-terraform

# Build the command inside the container.
RUN go install tmp/hello-go-ecs-terraform

# Run the command by default when the container starts.
ENTRYPOINT ["/go/bin/hello-go-ecs-terraform", "-port", "8080"]

EXPOSE 8080
