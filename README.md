# PrayTime

PrayTime is a small program written in vala which find timings of Islamic Prayer
and play the adhan at the given time.

PrayTime use the api on aladhan.com to retriew timings.

## Prerequisites

valac curl meson ninja glib gobject json-glib gstreamer pluie-echo

see meson.build 

```
glib_dep      = dependency('glib-2.0')
gobject_dep   = dependency('gobject-2.0')
gio_dep       = dependency('gio-2.0')
json_dep      = dependency('json-glib-1.0')
gstreamer_dep = dependency('gstreamer-1.0')
echo_dep      = dependency('pluie-echo-0.2')
```

on debian or debian like you can do :
```
$ sudo apt-get install valac libjson-glib-dev libgstreamer1.0-dev libgstreamer0.10-dev meson ninja-build
```
there is not yet a package for pluie-echo dependency, but you can install it with :
```
cd /tmp/
git clone https://github.com/pluie-org/libpluie-echo.git --branch latest --single-branch
cd libpluie-echo
meson --prefix=/usr ./ build
sudo ninja install -C build
```


## Install

git clone the project then cd to project and do :

```
meson --prefix=/usr ./ build
sudo ninja install -C build
```

## Configuration

```
[Params]
# see api.aladhan.com
city                     = Paris
country                  = FR
method                   = 3
latitudeAdjustmentMethod = 3

[Volumes]
# you can use same volume for all prayer
default                 = 1.00
# or adjust volume to specific prayer
fajr                     = 0.30
dhuhr                    = 0.70
asr                      = 0.40
# maghrib use default volume
maghrib                  = 
isha                     = 0.40

[Adhan]
# you can use same file for all prayer
default                  = /home/a-sansara/Dev/Vala/4006.mp3
# or define specific file for each prayer
fajr                     = /home/a-sansara/Dev/Vala/Adhan-Fajr-Makkah-Sheikh-Ali-Ahmed-Mulla.ogg
dhuhr                    = /home/a-sansara/Dev/Vala/Filipino-Adhan.ogg
asr                      = /home/a-sansara/Dev/Vala/azan.ogg
maghrib                  = /home/a-sansara/Dev/Vala/adhan.ogg
# isha use default file
isha                     = 

[Cron]
# timings updating time
time                     = 00:00
```

## Usage

![praytime usage](https://www.meta-tech.academy/img/praytime-usage.png?tmp=2)


First step is to edit configuration file
```
/usr/share/praytime.praytime.ini
```

Set your city & location, then add some adhan file

After that you can initialise the cron installation with

```
$ praytime cron
```
![praytime cron](https://www.meta-tech.academy/img/praytime-cron.png?tmp=1)


you can test adhan with :

```
# Fajr or other prayer
praytime play Fajr
```
![praytime play adhan](https://www.meta-tech.academy/img/praytime-play.png?tmp=1)


to see current timings simply do :
```
$ praytime
```
![praytime timings](https://www.meta-tech.academy/img/praytime-timings.png?tmp=1)

the red star indicates coming prayers

