
CA_ROOT_DIR?=$(PWD)

export IP_INFO=$$(curl -s http://ipinfo.io/json | jq -c .)
CITY=$(shell echo $(IP_INFO) | jq -r '.city')
REGION=$(shell echo $(IP_INFO) | jq -r '.region')
COUNTRY=$(shell echo $(IP_INFO) | jq -r '.country')

GO=/usr/local/go/bin/go
GO_VERSION=1.20
GO_TAR=go$(GO_VERSION).linux-amd64.tar.gz

CFSSL=/usr/local/bin/cfssl
CFSSL_SRC=/src/cfssl

CA=$(CA_ROOT_DIR)/ca
CA_PEM=$(CA).pem
CA_KEY_PEM=$(CA)-key.pem
CA_JSON=$(CA).json
CA_CSR=$(CA).csr
CA_CSR_JSON=$(CA)-csr.json

FILES=$(CA_PEM) $(CA_KEY_PEM) $(CA_JSON) $(CA_CSR_JSON) $(CA_CSR) $(GO_TAR)
DIRS=$(CFSSL_SRC)

define CA_JSON_TEMPLATE
{
    "signing": {
        "default": {
            "expiry": "8760h"
        },
        "profiles": {
            "server": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            }
        }
    }
}
endef

define CA_CSR_TEMPLATE
{
    "CN": "Vault CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "<country>",
            "L": "<city>",
            "O": "Vault",
            "ST": "<region>"
        }
    ]
}
endef

.PHONY: all
all: ca

$(GO_TAR):
	wget https://dl.google.com/go/$(GO_TAR)

$(GO): $(GO_TAR)
	sudo tar -C /usr/local -xzf $(GO_TAR)
	sudo touch $(GO)
	grep -qxF 'export PATH=$$PATH:/usr/local/go/bin' /etc/profile || echo 'export PATH=$$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile > /dev/null

$(CFSSL_SRC):
	sudo git clone https://github.com/cloudflare/cfssl.git $(CFSSL_SRC)
	sudo chown -R $(USER):$(USER) $(CFSSL_SRC)



$(CFSSL): $(CFSSL_SRC) $(GO)
# export PATH=$(PATH):/usr/local/go/bin
	cd $(CFSSL_SRC) && PATH=$(PATH):/usr/local/go/bin make
	sudo cp $(CFSSL_SRC)/bin/* /usr/local/bin


$(CA_JSON): CA_JSON_TEMPLATE
$(CA_JSON):
	echo $$CA_JSON_TEMPLATE | sudo tee $(CA_JSON)> /dev/null


export CA_CSR_TEMPLATE
$(CA_CSR_JSON):
	echo $$CA_CSR_TEMPLATE | sudo tee $(CA_CSR_JSON) > /dev/null


$(CA_PEM): $(CA_CSR_JSON)
	cfssl gencert -initca $(CA_CSR_JSON) | cfssljson -bare ca
	@echo Generated $(CA_PEM)



.PHONY: usage
usage:
	@echo "tada"
	@echo "City: $(CITY)"
	@echo "Region: $(REGION)"
	@echo "Country: $(COUNTRY)"



.PHONY: ca
ca: $(CA_PEM) $(CA_KEY_PEM)

.PHONY: go
go: $(GO)

.PHONY: cfssl
cfssl: $(CFSSL)

.PHONY: clean
clean:
	-sudo rm $(FILES)
	-sudo rm -Rf $(DIRS)