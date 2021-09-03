<IfModule mod_ssl.c>
	<VirtualHost *:443>
		ServerName prod-instana.@@INSTANA_FQDN
		SSLEngine on
		SSLProxyEngine On
		ProxyRequests Off
		SSLProxyCheckPeerName off
		ProxyPreserveHost On
		SSLCertificateFile @@DEPLOY_LOCAL_WORKDIR/tls.crt
		SSLCertificateKeyFile @@DEPLOY_LOCAL_WORKDIR/tls.key
		ProxyPass / https://prod-instana.@@INSTANA_FQDN:9443/
		ProxyPassReverse / https://prod-instana.@@INSTANA_FQDN:9443/
	</VirtualHost>

	<VirtualHost *:443>
		ServerName @@INSTANA_FQDN
		SSLEngine on
		SSLProxyEngine On
		ProxyRequests Off
		SSLProxyCheckPeerName off
		ProxyPreserveHost On
		SSLCertificateFile @@DEPLOY_LOCAL_WORKDIR/tls.crt
		SSLCertificateKeyFile @@DEPLOY_LOCAL_WORKDIR/tls.key
		ProxyPass / https://@@INSTANA_FQDN:8443/
		ProxyPassReverse / https://@@INSTANA_FQDN:8443/
	</VirtualHost>
</IfModule>
