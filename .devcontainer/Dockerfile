FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

# The base image ships a Yarn apt repo whose signing key no longer verifies,
# which makes every "apt-get update" (and the docker-in-docker feature) fail.
# We don't use Yarn, so drop that repo.
RUN rm -f /etc/apt/sources.list.d/yarn.list
