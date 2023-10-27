.PHONY: clean package push

PROJECT=kiwitcms
REGISTRY:=registry-1.docker.io/crazytje
VERSION:=$(shell cat VERSION | tr --delete '/n')

clean:
	rm -rf build

package: clean
	mkdir -p ./build && cd build && helm package ../chart && cd -

push:
	helm push build/*.tgz "oci://${REGISTRY}"
