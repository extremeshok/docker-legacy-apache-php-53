#!/bin/bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################

#ensure this only runs once per a startup
if [ ! -f "/tmp/fixed_ownership" ] ; then
  echo "Setting ownership of /var/www to www-data in the background"
  echo "yes" > /tmp/fixed_ownership
  chown -R --silent www-data:www-data /var/www &
fi

echo "launching supervisord"
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
