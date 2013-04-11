Squiz Matrix Scripts
=============
Various helpful scripts for Squiz Matrix.

squiz_matrix_install.sh
---

This script will install Squiz Matrix automatically. The process takes about 5 minutes. This has been tested on Debian Squeeze.

### Usage: 
``` 
sh /path/to/script/squiz_matrix_install.sh
```

### Options:  
```
ROOT_URL="192.168.163.131"  
DEFAULT_EMAIL="me@website.com"  
PATH_TO_MATRIX="/home/websites"  
APACHE_USER="www-data"  
SQUIZ_MATRIX_VERSION="mysource_4-14-1"
```

morph_assets.php
---

This script will morph assets under a specified root node. E.g. backend_user to user. The script will let you know how many 
assets are available to morph then will prompt you to continue.

### Usage: 
``` 
php morph_assets.php /path/to/matrix <root id> <from asset type code> <to asset type code>
```

### Options:  
```
--simulate // Optional mode as last argument to simulate the morphing process
```

