#!/bin/bash

#ensure this only runs once per a startup
if [ ! -f "/tmp/fixed_ownership" ] ; then
  echo "Setting ownership of /var/www to www-data in the background"
  echo "yes" > /tmp/fixed_ownership
  chown -R --silent www-data:www-data /var/www &
fi

echo "launching supervisord"
exec /usr/bin/supervisord
