######################################################################
#
#	Make file to be installed in /etc/raddb/certs to enable
#	the easy creation of certificates.
#
#	See the README file in this directory for more information.
#
#	$Id: 34948bd9248a6953de3696abcd2088a7a5cee014 $
#
######################################################################

DH_KEY_SIZE	= 2048
OPENSSL		= openssl
EXTERNAL_CA	= $(wildcard external_ca.*)

ifneq "$(EXTERNAL_CA)" ""
PARTIAL		= -partial_chain
endif

#
#  Set the passwords
#
include passwords.mk

######################################################################
#
#  Make the necessary files, but not client certificates.
#
######################################################################
# Find all web-server configuration files
WEB_SERVER_CONFIGS := $(wildcard web-server*.cnf)
WEB_SERVER_NAMES := $(basename $(WEB_SERVER_CONFIGS))
WEB_SERVER_CERTS := $(addsuffix .pem,$(WEB_SERVER_NAMES))

.PHONY: all
all: index.txt serial ca server client web-server

.PHONY: web-server
web-server: $(WEB_SERVER_CERTS)

define make-web-server-cert
$(1).pem: $(1).p12
	$(OPENSSL) pkcs12 -in $(1).p12 -out $(1).pem -passin pass:$(PASSWORD_SERVER) -passout pass:$(PASSWORD_SERVER)
	chmod g+r $(1).pem

$(1).p12: $(1).crt
	$(OPENSSL) pkcs12 -export -in $(1).crt -inkey $(1).key -out $(1).p12 -passin pass:$(PASSWORD_SERVER) -passout pass:$(PASSWORD_SERVER)
	chmod g+r $(1).p12

$(1).crt: ca.key ca.pem $(1).csr
	$(OPENSSL) ca -batch -keyfile ca.key -cert ca.pem -in $(1).csr -key $(PASSWORD_CA) -out $(1).crt -extensions xpserver_ext -extfile xpextensions -config ./$(1).cnf

$(1).csr $(1).key: $(1).cnf
	$(OPENSSL) req -new -out $(1).csr -keyout $(1).key -config ./$(1).cnf
	chmod g+r $(1).key
endef

$(foreach cert,$(WEB_SERVER_NAMES),$(eval $(call make-web-server-cert,$(cert))))

.PHONY: client
client: client.pem

.PHONY: ca
ca: ca.der ca.crl

.PHONY: server
server: server.pem server.vrfy

.PHONY: inner-server
inner-server: inner-server.pem inner-server.vrfy

.PHONY: verify
verify: server.vrfy client.vrfy $(addsuffix .vrfy,$(WEB_SERVER_NAMES))

.PHONY: debug
debug:
	@echo "WEB_SERVER_CONFIGS = $(WEB_SERVER_CONFIGS)"
	@echo "WEB_SERVER_NAMES = $(WEB_SERVER_NAMES)"
	@echo "WEB_SERVER_CERTS = $(WEB_SERVER_CERTS)"

.PHONY: %.vrfy
%.vrfy: ca.pem %.pem
	@$(OPENSSL) verify $(PARTIAL) -CAfile ca.pem $*.pem

######################################################################
#
#  Diffie-Hellman parameters
#
######################################################################
index.txt:
	@touch index.txt

serial:
	@echo '01' > serial

passwords.mk: server.cnf ca.cnf client.cnf inner-server.cnf
	@echo "PASSWORD_SERVER = '$(shell grep output_password server.cnf | sed 's/.*=//;s/^ *//')'"> $@
	@echo "PASSWORD_INNER = '$(shell grep output_password inner-server.cnf | sed 's/.*=//;s/^ *//')'">> $@
	@echo "PASSWORD_CA = '$(shell grep output_password ca.cnf | sed 's/.*=//;s/^ *//')'">> $@
	@echo "PASSWORD_CLIENT = '$(shell grep output_password client.cnf | sed 's/.*=//;s/^ *//')'">> $@
	@echo "USER_NAME = '$(shell grep emailAddress client.cnf | grep '@' | sed 's/.*=//;s/^ *//')'">> $@
	@echo "CA_DEFAULT_DAYS = '$(shell grep default_days ca.cnf | sed 's/.*=//;s/^ *//')'">> $@

######################################################################
#
#  Create a new self-signed CA certificate
#
######################################################################
ca.key ca.pem: ca.cnf
	@[ -f index.txt ] || $(MAKE) index.txt
	@[ -f serial ] || $(MAKE) serial
	$(OPENSSL) req -new -x509 -keyout ca.key -out ca.pem \
		-days $(CA_DEFAULT_DAYS) -config ./ca.cnf \
		-passin pass:$(PASSWORD_CA) -passout pass:$(PASSWORD_CA)
	chmod g+r ca.key

ca.der: ca.pem
	$(OPENSSL) x509 -inform PEM -outform DER -in ca.pem -out ca.der

ca.crl: ca.pem
	$(OPENSSL) ca -gencrl -keyfile ca.key -cert ca.pem -config ./ca.cnf -out ca-crl.pem -key $(PASSWORD_CA)
	$(OPENSSL) crl -in ca-crl.pem -outform der -out ca.crl
	rm ca-crl.pem

######################################################################
#
# Create a new server certificate
#
######################################################################
server.csr server.key: server.cnf
	$(OPENSSL) req -new -out server.csr -keyout server.key -config ./server.cnf
	chmod g+r server.key

server.crt: ca.key ca.pem server.csr
	$(OPENSSL) ca -batch -keyfile ca.key -cert ca.pem -in server.csr -key $(PASSWORD_CA) -out server.crt -extensions xpserver_ext -extfile xpextensions -config ./server.cnf

server.p12: server.crt
	$(OPENSSL) pkcs12 -export -in server.crt -inkey server.key -out server.p12 -passin pass:$(PASSWORD_SERVER) -passout pass:$(PASSWORD_SERVER)
	chmod g+r server.p12

server.pem: server.p12
	$(OPENSSL) pkcs12 -in server.p12 -out server.pem -passin pass:$(PASSWORD_SERVER) -passout pass:$(PASSWORD_SERVER)
	chmod g+r server.pem

.PHONY: server.vrfy
server.vrfy: ca.pem
	@$(OPENSSL) verify $(PARTIAL) -CAfile ca.pem server.pem

######################################################################
#
#  Create a new client certificate, signed by the the above server
#  certificate.
#
######################################################################
client.csr client.key: client.cnf
	$(OPENSSL) req -new -out client.csr -keyout client.key -config ./client.cnf
	chmod g+r client.key

client.crt: ca.key ca.pem client.csr
	$(OPENSSL) ca -batch -keyfile ca.key -cert ca.pem -in client.csr -key $(PASSWORD_CA) -out client.crt -extensions xpclient_ext -extfile xpextensions -config ./client.cnf

client.p12: client.crt
	$(OPENSSL) pkcs12 -export -in client.crt -inkey client.key -out client.p12 -passin pass:$(PASSWORD_CLIENT) -passout pass:$(PASSWORD_CLIENT)
	chmod g+r client.p12
	cp client.p12 $(USER_NAME).p12

client.pem: client.p12
	$(OPENSSL) pkcs12 -in client.p12 -out client.pem -passin pass:$(PASSWORD_CLIENT) -passout pass:$(PASSWORD_CLIENT)
	chmod g+r client.pem
	cp client.pem $(USER_NAME).pem

.PHONY: client.vrfy
client.vrfy: ca.pem client.pem
	c_rehash .
	$(OPENSSL) verify -CApath . client.pem

######################################################################
#
#  Create a new inner-server certificate, signed by the above CA.
#
######################################################################
inner-server.csr inner-server.key: inner-server.cnf
	$(OPENSSL) req -new  -out inner-server.csr -keyout inner-server.key -config ./inner-server.cnf
	chmod g+r inner-server.key

inner-server.crt: ca.key ca.pem inner-server.csr
	$(OPENSSL) ca -batch -keyfile ca.key -cert ca.pem -in inner-server.csr  -key $(PASSWORD_CA) -out inner-server.crt -extensions xpserver_ext -extfile xpextensions -config ./inner-server.cnf

inner-server.p12: inner-server.crt
	$(OPENSSL) pkcs12 -export -in inner-server.crt -inkey inner-server.key -out inner-server.p12  -passin pass:$(PASSWORD_INNER) -passout pass:$(PASSWORD_INNER)
	chmod g+r inner-server.p12

inner-server.pem: inner-server.p12
	$(OPENSSL) pkcs12 -in inner-server.p12 -out inner-server.pem -passin pass:$(PASSWORD_INNER) -passout pass:$(PASSWORD_INNER)
	chmod g+r inner-server.pem

.PHONY: inner-server.vrfy
inner-server.vrfy: ca.pem
	@$(OPENSSL) verify $(PARTIAL) -CAfile ca.pem inner-server.pem

######################################################################
#
#  Miscellaneous rules.
#
######################################################################
print:
	$(OPENSSL) x509 -text -in server.crt

printca:
	$(OPENSSL) x509 -text -in ca.pem

clean:
	@rm -f *~ *old client.csr client.key client.crt client.p12 client.pem \
		web-server*.csr web-server*.key web-server*.crt web-server*.p12 web-server*.pem

destroycerts: clean
	rm -f *~ dh *.csr *.crt *.p12 *.der *.pem *.key index.txt* \
			serial*  *\.0 *\.1 ca-crl.pem ca.crl
