coffee -o js/ -bc cmd.coffee import.coffee

# put the shebang at the top of the command line program
echo '#!/usr/bin/env node' | cat - js/cmd.js > /tmp/cmd.js && mv /tmp/cmd.js js/cmd.js
chmod +x js/cmd.js