<IfModule mod_ssl.c>
	<VirtualHost *:443>
		ServerName prod-instana.@@INSTANA_HOST
		SSLEngine on
		SSLProxyEngine On
		ProxyRequests Off
		SSLProxyCheckPeerName off
		ProxyPreserveHost On
		SSLCertificateFile @@DEPLOY_LOCAL_WORKDIR/tls.crt
		SSLCertificateKeyFile @@DEPLOY_LOCAL_WORKDIR/tls.key
		ProxyPass / https://prod-instana.@@INSTANA_HOST:9443/
		ProxyPassReverse / https://prod-instana.@@INSTANA_HOST:9443/
	</VirtualHost>

	<VirtualHost *:443>
		ServerName @@INSTANA_HOST
		SSLEngine on
		SSLProxyEngine On
		ProxyRequests Off
		SSLProxyCheckPeerName off
		ProxyPreserveHost On
		SSLCertificateFile @@DEPLOY_LOCAL_WORKDIR/tls.crt
		SSLCertificateKeyFile @@DEPLOY_LOCAL_WORKDIR/tls.key
		ProxyPass / https://@@INSTANA_HOST:8443/
		ProxyPassReverse / https://@@INSTANA_HOST:8443/
	</VirtualHost>
</IfModule>
