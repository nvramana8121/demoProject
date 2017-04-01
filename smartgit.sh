#!/bin/bash
#
# Editing this script should not be required.
#
# To specify an alternative Java Runtime Environment, set the environment
# variable SMARTGIT_JAVA_HOME or add a
#
# jre=/path/to/jre
#
# line to smartgit.vmoptions (see below).
#
# To specify additional VM options, add them to smartgit.vmoptions
# or ~/.smartgit/smartgit.vmoptions files.

parseVmOptions() {
  if [ -f $1 ]; then
    while read LINE || [[ -n "$LINE" ]]; do
      LINE="${LINE#"${LINE%%[![:space:]]*}"}"
      if [ ${#LINE} -gt 0 ] && [ ! ${LINE:0:1} == '#' ]; then
        if [ ${LINE:0:4} == 'jre=' ]; then
          SMARTGIT_JAVA_HOME="${LINE:4}"
        elif [ ${LINE:0:5} == 'path=' ]; then
          SMARTGIT_PATH="$SMARTGIT_PATH:${LINE:5}"
        else
          _VM_PROPERTIES="$_VM_PROPERTIES $LINE"
        fi
      fi
    done < $1
  fi
}

echoJreConfigurationAndExit() {
  echo "Add the line"
  echo "jre=/path/to/jre"
  echo "to ~/.smartgit/smartgit.vmoptions and change the path"
  echo "to the one pointing to the desired JRE."
  exit 1
}

case "$BASH" in
    */bash) :
        ;;
    *)
        exec /bin/bash "$0" "$@"
        ;;
esac

# Resolve the location of the SmartGit installation.
# This includes resolving any symlinks.
PRG=$0
while [ -h "$PRG" ]; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '^.*-> \(.*\)$' 2>/dev/null`
  if expr "$link" : '^/' 2> /dev/null >/dev/null; then
    PRG="$link"
  else
    PRG="`dirname "$PRG"`/$link"
  fi
done

SMARTGIT_BIN=`dirname "$PRG"`

# Absolutize dir
oldpwd=`pwd`
cd "${SMARTGIT_BIN}";
SMARTGIT_BIN=`pwd`
cd "${oldpwd}";
unset oldpwd

SMARTGIT_HOME=`dirname "$SMARTGIT_BIN"`

parseVmOptions $SMARTGIT_BIN/smartgit.vmoptions
parseVmOptions ~/.smartgit/smartgit.vmoptions

# Determine Java Runtime
if [ "$SMARTGIT_JAVA_HOME" = "" ] ; then
	SMARTGIT_JAVA_HOME=$SMARTGITHG_JAVA_HOME
fi
if [ "$SMARTGIT_JAVA_HOME" = "" ] ; then
	SMARTGIT_JAVA_HOME=$JAVA_HOME
fi

_JAVA_EXEC="java"
if [ "$SMARTGIT_JAVA_HOME" != "" ] ; then
    _TMP="$SMARTGIT_JAVA_HOME/bin/java"
    if [ -f "$_TMP" ] ; then
        if [ -x "$_TMP" ] ; then
            _JAVA_EXEC="$_TMP"
        else
            echo "Warning: $_TMP is not executable"
        fi
    else
        echo "Warning: $_TMP does not exist"
    fi
fi

if ! which "$_JAVA_EXEC" >/dev/null 2>&1 ; then
    echo "Error: No java environment found (JRE 1.8 or higher required)."
    echoJreConfigurationAndExit
fi

# check that the environment is 1.8 or higher
JAVA_VERSION=$($_JAVA_EXEC -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [[ "$JAVA_VERSION" < "1.8" ]]; then
    echo "Java version 1.8 or higher is required, currently $JAVA_EXEC is used (version $JAVA_VERSION)"
    echoJreConfigurationAndExit
fi

# this seems necessary for Solaris to find the Cairo-library
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/lib/gnome-private/lib

if type "lsb_release" > /dev/null 2> /dev/null ; then
    if [ "$XDG_CURRENT_DESKTOP" == "Unity" ] ; then
        # work-around for https://bugs.eclipse.org/bugs/show_bug.cgi?id=419729
        # work-around for https://bugs.eclipse.org/bugs/show_bug.cgi?id=502056
        export UBUNTU_MENUPROXY=0

        # Without the following line sliders are not visible in Ubuntu 12.04
        # (see <https://bugs.eclipse.org/bugs/show_bug.cgi?id=368929>)
        export LIBOVERLAY_SCROLLBAR=0
    fi
fi

if [ "$KDE_SESSION_UID" != "" ] && [ "$GTK2_RC_FILES" == "" ] ; then
	if grep -q "oxygen-gtk" "$HOME/.gtkrc-2.0-kde4"; then
		echo "Please change the GTK+ theme to something else than oxygen-gtk."
		echo "See also http://www.syntevo.com/blog/?p=4143"
		exit -1
	fi
fi

# as workaround for https://bugs.eclipse.org/bugs/show_bug.cgi?id=435773
export SWT_GTK3=0

_GC_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:InitiatingHeapOccupancyPercent=25 -Xmx768m"
_MISC_OPTS="-Xverify:none -XX:MaxJavaStackTraceDepth=1000000 -Dsun.io.useCanonCaches=false"

SMARTGIT_PATH="$PATH$SMARTGIT_PATH"

(export PATH="$SMARTGIT_PATH"; $_JAVA_EXEC $_GC_OPTS $_MISC_OPTS $_VM_PROPERTIES -jar "$SMARTGIT_HOME/lib/bootloader.jar" "$@")

