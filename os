#!/bin/sh
if eval 'uname > /dev/null 2> /dev/null'; then
  case `uname -s` in
    Linux*)
      echo "linux";;
    CYGWIN*|Cygwin*|cygwin*)
      echo "cygwin";;
    SunOS*|sunos*|Sunos*)
      echo "sunos";;
    Darwin*|darwin*)
      echo "darwin";;
    *)
      echo "unix";;
  esac
else
  echo "unknown"
fi
