VERSION=0.1.0

build:
ifeq ("$(ENV)","dev")
	@echo 'Construindo imagem - DEV'
	docker build --target development -t terraform-aws-101:dev-${VERSION} .

else ifeq ("$(ENV)","prod")
	@echo 'construindo imagem - PROD'
	docker build --target production -t terraform-aws-101:${VERSION} .

else
	@echo 'Ambiente não selecionado'
	@echo 'Opções válidas: ENV=[dev,prod]'
	@echo '-- make build ENV=dev --'
endif

run:
	docker run --rm --name terraform-aws-101 -v `pwd`/app:/app -p 8000:8000 -it terraform-aws-101:dev-${VERSION}
