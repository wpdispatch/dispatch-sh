# dispatch-sh

## About

Shell script for setting up a new WordPress project

## Usage

`cd` to the root of your new project
```sh
curl -v --fail --output 'dispatch-sh.sh' https://raw.githubusercontent.com/wpdispatch/dispatch-sh/master/dispatch-sh.sh
curl -v --fail --output 'dispatch-sh.yml' https://raw.githubusercontent.com/wpdispatch/dispatch-sh/master/dispatch-sh.example.yml
```
edit `dispatch-sh.yml`
```sh
bash dispatch-sh.sh
```

## Credits

this project was inspired by [WPDistillery](https://github.com/flurinduerst/WPDistillery)