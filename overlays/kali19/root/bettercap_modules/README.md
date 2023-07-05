# OPFOR Power Human-Machine Interface (HMI) Man-in-the-Middle (MitM)
Usage instructions, tips, and effects of the power HMI MitM are included in this document. NOTE: this attack targets only the power system HMI; it cannot be used as is to affect the fuel system HMI. The VM used to launch this attack must be present on the same subnet (LAN) as the target machine because it makes use of ARP spoofing. This module makes use of Bettercap v2 to launch the ARP spoof, start an HTTP proxy, and intercept and modify traffic destined for the target machine.     

Bettercap v2 is a MitM tool written in Go. Documentation for Bettercap v2 can be found here: [here](https://www.bettercap.org/). Bettercap uses caplet files or its interactive command line interface to start modules such as spoofers, proxies, and recon. Bettercap proxies can be used to intercept and respond to network traffic using Javascript scripts. The main MitM modules described here intercept and modify or dump HTTP responses destined for the HMI.

## Usage
A Bash run script has been created that starts Bettercap with the necessary arguments to launch the MitM. NOTE: The script must be run as root (Bettercap requires it).    
```
# ./run_hmi_mitm.bash
```

The run script contains a simple Bash command of the form `bettercap --caplet <caplet_path>`. Any `bettercap` caplet can be started by replacing `<caplet_path>` with the file path to the caplet file.    

Another caplet has been included, `http-dump.cap` that dumps the incoming packets destined for the target machine in a human-readable format. This caplet also dumps JSON application data with a format resembling that of the HMI views to a `.txt` file for HMI spoofing. It can be run using the `bettercap` command described above.

## When to Use
The HMI MitM script should be used when the user would like to spoof the power system HMI values and connections. The VM executing Bettercap must be present on the target machine's subnet (LAN).    

The HTTP response dump script should be used to observe HTTP responses to the HMI without modifying traffic. If HMI views have been modified such that the HMI MitM is no longer effective, the HTTP response dump script may be used to **overwrite** the text files containing the JSON application data to inject.


## Effects
The HMI MitM script intercepts HTTP responses destined to the HMI and modifies application data to spoof the power system values and connections. While the MitM is in effect, the power system values and connections displayed on the HMI will not chang, regardless of the ground truth.   


## How it Works
The HMI MitM uses Bettercap to ARP spoof the LAN, start an HTTP proxy, and intercept and modify HTTP responses destined for the HMI. When an HTTP response packet containing JSON data of the form of an HMI view update is encountered, the Bettercap HTTP proxy script will replace the JSON data with previously recorded, static JSON data. The previously recorded JSON data is stored in a series of `.txt` files in the `custom_modules` directory. After the JSON application data is replaced, the packet is forwarded to the HMI, where the HMI view is updated according to the newly received data. In this way, the HMI receives the same values for each value and connection in each view, regardless of the ground truth values.


## Troubleshooting
If the Bash run script is not exeutable, change its permissions to allow execution: `# chmod +x ./run_hmi_mitm.bash`   

If Bettercap is started but the MitM is not working/isn't forwarding modified packets, check to make sure the proxy settings have been cleared. `env | grep -i proxy` should return no results. If the proxy is set, each environment variable can be cleared using the `unset` Bash command: `unset http_proxy; unset https_proxy`