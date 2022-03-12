# OrgLess

Container for organizr utilizing the new data folder for data storage

```sh
docker run -d \
  --name=organizr \
  -e PUID=1000 `#optional` \
  -e PGID=1000 `#optional` \
  -e TZ=Europe/Oslo \
  -p 80:80 \
  -v /path/to/appdata/organizr:/var/www/data \
  -v /path/to/appdata/config:/config `#optional` \
  --restart unless-stopped \
  docker.roxedus.net/roxedus/org-less
```

`/var/www/data` holds appdata. This path should be safe to store the database in aswell.
`/config` Is a optional path, it holds nginx and php logs, aswell as mechanisms for tweaking those systems.
