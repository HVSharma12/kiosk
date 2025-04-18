# Kiosk

This project is a collection of container builds and deployment yaml to run kiosk applications as containers with Kubernetes (or Podman). This is achieved by running X11 and PulseAudio inside of containers then sharing their sockets with a container that runs the workload.

The container builds are done using OpenSUSE's instance of the Open Build Service and can be found at https://build.opensuse.org/project/show/home:atgracey:wallboardos

# Benefits

Running your kiosk/HID applications this way allows for more explicit security boundaries along with allowing for a wider range of languages/frameworks when building your app.

# Architecture

The Kubernetes Pod contains the three containers (X11, PulseAudio, and the workload itself)

The workload and X11 containers use a unix socket that's created in an EmptyDir to allow communication between containers. They also use an EmptyDir to share an auth token.

The workload and PulseAudio containers communicate over the shared local network within the Pod.

Both the PulseAudio and X11 containers use udev to communicate with the hardware. (That's a slight oversimplification...)

![Architecture](/architecture.png)

## Startup Flow

When the server is starting up, here's the order of which components control what's being shown on the display.

- UEFI (Firmware)

The first thing you see is determined by the system's firmware. Different system manufactures provide more or less control over this portion of the process.

- Grub Bootloader

Grub then takes over from the firmware and shows the boot menu. This step can be branded or skipped depending on needs.

- Linux Framebuffer device

Once the system starts booting and execution is handed from the bootloader to the linux kernel, the system will start displaying logs or other basic graphics. The logs can be removed by adding `quiet` to the kernel arguments and we can write an image directly to the framebuffer.

- X11 

When X11 starts up, it will take over the display and show a desktop. When we don't run a taskbar or any applications, you will only see the background. By replacing the background, you can change what's displayed while the application is starting.

- Application

Lastly, the application itself will be composited on top of the background. For most kiosk applications, you will likely want to have this be fullscreen so the background becomes hidden.


## Failure modes

The steps above (after GRUB) stack above each other so if a layer fails, you should see the layer below it. For example, if the application fails you will see the X11 background while the app container is being restarted and, if X11 is restarted, you will see the framebuffer.


# Running the basic demo

To run the basic demo in Kubernetes:
- Install a Linux and boot to a command line instead of a desktop environment
- Install [K3s](https://k3s.io) or Kubernetes distribution of your choice (v1.29 or newer)
- Download or clone this repo
- Run `kubectl apply -f ./yaml/basic.yaml`

# Building a custom application

If you want to replace firefox with your own application, you need to build your application into an OCI container image. 

The application container needs the appropriate libraries to be able to communicate with X11. For Electron apps, here are the libraries required:

- `libX11-xcb1`
- `libgtk-3-0`
- `mozilla-nss`
- `xorg-x11-fonts`
- `libpulse0`
- `libavcodec58`
- `libasound2` 
- `npm-default`
- `nodejs-default`

For an example workload and Dockerfile, check out the [electron app in this repo](./electron-example/)

# Work that I would like to get to in the future

- Replace X11 with Wayland using the [Cage project](https://github.com/cage-kiosk/cage)
- Replace PulseAudio with Pipewire
- Reduce installed packages (and container size) as possible
- Build a [buildpack](https://buildpacks.io) for Electron
- Document usage with [Epinio](https://epinio.io) to improve DX
- Rename project to something more interesting?


# Misc how-to's (to reorganize)

## Removing console output during boot

Adding `quiet` to your kernel bootargs will remove the text that is seen on boot of linux systems.

Masking `console-getty.service` and `getty@tty1.service` will remove the login prompt. 

Doing both of these will show a blank screen with a flashing cursor in the top-left corner. To show something on screen between the GRUB splash screen, you could use `plymouth` or just `cat` a raw framebuffer file to `/dev/fb0`. (Check out https://github.com/zqb-all/convertfb for a tool on converting images to the right format)

## Turning off key combinations

To disallow closing the application or otherwise tampering with the kiosk, it can be useful to remap or turn of certain keys. This can be done using [xmodmap](https://linux.die.net/man/1/xmodmap)

The helm chart allows for customizing this file with a values.yaml that looks like this: 

```
X11:
  keyboardModMap: |
    clear control
    clear mod1
    clear mod2 
    clear mod3
    clear mod4
    clear mod5
    keycode  66 =
    keycode 108 =
    keycode 133 =
    keycode 134 =
    keycode 150 =
    keycode 204 =
    keycode 205 =
    keycode 206 =
    keycode 207 =
```

## Adding Hostname Resolution

The helm chart allows for adding additional hostname resolution in case your workload needs to refer to static ip addresses: 

```
hostAliases:
- hostnames:
  - "cockpit.local"
  ip: "172.16.0.1"
```

## Connecting with Self Signed Certs

If your UI needs to load from locations that are secured with self-signed certificates, this is complicated by Chromium (and related stacks such as Electron) using it's own trust store for certificates so you need to load a new one in seperately.

To do this, you can build a generic secret with an nssdb files with a script that looks like this:

```
#!/bin/bash
export NSSDB=/tmp/cert/nssdb


# Create new self-signed cert
openssl req -x509 -sha256 -days 36500 -keyout mycert.key -out mycert.crt -nodes -subj "/C=US/ST=CA/O=OC/OU=Org/CN=myhost.local" -addext "subjectAltName = DNS:myhost.local"

# Create P12 cert from self-signed
openssl pkcs12 -export -out mycert.p12 -inkey mycert.key -in mycert.crt -passout pass: -name mycert

# Create NSSDB files 
mkdir -p $NSSDB
certutil -d sql:$NSSDB -N --empty-password 

# Import P12 cert to NSSDB and add permissions
pk12util -d sql:$NSSDB -i mycert.p12 -W ""
certutil -d sql:$NSSDB -M -n "mycert" -t "TCu,,"

# Create secret from files on disk
kubectl create secret generic nssdb -n kiosk --from-file=$NSSDB
```

Then add the following to your helm values:

```
workload: 
  nssdbSecretName: nssdb
```

## Forcing a specific resolution

Most displays will negotiate the best resolution possible but sometimes you may want to force a specific resolution. To achieve this, you can overwrite the script that does the display setup with the xinitrcOverride helm value:

```
X11:
  xinitrcOverride: |
    #!/bin/bash
    xset -dpms
    xset s off
    xset s noblank
    DISPLAY=:0

    # Don't edit this part
    [ ! -d "/home/user/xauthority" ] && mkdir -p "/home/user/xauthority"
    touch /home/user/xauthority/.xauth
    xauth -i -f /home/user/xauthority/.xauth generate $DISPLAY . trusted
    chown -R user:users /home/user/xauthority

    # Get output name (assumes a single display)
    OUTPUT=`xrandr |grep "\ connected" | cut -d " " -f1`

    # Set resolution
    xrandr --output $OUTPUT --mode 1920x1080

    ( [ -f ~/.Xmodmap ] ) && xmodmap ~/.Xmodmap

    exec icewm-session-lite
```

## Remote Debugging the browser 

Chromium based browsers (including Firefox and Electron) allow for attaching a remote debugger/developer tools. 

TODO: Test and write up how to expose the port and connect to it. (and likely add flag in helm chart)


## Change /dev/shm size

By default, we mount in an in-memory tmpfs to be used by the application. The limit for this volume is set to 256Mi but can be adjusted with the following helm values:

```
workload:
  shm:
    sizeLimit: <the limit you want>
```

If you don't want or need this volume for your application, you can disable it with:

```
workload:
  shm:
    enabled: false
```
