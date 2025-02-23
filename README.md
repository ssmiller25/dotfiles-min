# dotfiles-min
A minimal dotfile configuration

To Encode a secret

```
find .ssh .aws -type f | grep -v -e pub -e known_hosts -e secrets -e private | tar -czvf homeconfig.tar.gz -T -
cat homeconfig.tar.gz | base64 -w 0 > homeconfig.txt
```

Copy/paste the "homeconfig.txt" into a HOMECONFIG enviornment variables