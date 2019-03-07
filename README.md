# Overview

  This was created for a specific environment with specific needs. Realize it is 100% not perfect and a side project I worked on. This was the product of losing the original script I had written, which was much worse than this, and trying to port it to being an actual PowerShell module. That being said, YOU NEED THE POWERCLI POWERSHELL MODULE (Google how to install if needed)!

  The basic funtionality of this script is to feed it a CSV populated with all VM information needed. The script parses the CSV and performs whatever actions you choose based off of what VMType you provide as an argument. It isn't finished and a lot of the functionality is not coded yet, but the structure for everything is there and can easily be modified to suit whatever needs you may have.

  My intention is to eventually provide more examples of usage, but I do not currently have the time to do so, but I will give a quick set of examples.

# Examples

  First, deploy (from a template) Windows servers that will eventually be domain controllers for each student environment. 'Create' declares you are creating a VM, 'VMType' parses the CSV and only performs actions on whatever VM type you feed it, 'StartMachines' turns on all VMs after creation, 'NetworkMod' will modify the network backing for each VM, and 'File' is the file location for the CSV being used to gather all information needed for creating/modifying each VM. This process uses VMWare Customization which will IP address, name, and configure the VM upon creation.

Manage-VirtualMachines -Create -VMType DC -StartMachines -NetworkMod -File 'Actual filepath of CSV being used'
  
  Next, we would copy a PowerShell script to each server used to configure each student's domain (all are unique) and run it. This sets up the domain, forest, creates users/groups/computers, and allows all further Windows workstations to be deployed and automatically be domain joined. A copy of this script isn't here, but I can provide it too. There are many examples on the internet of the same task. 'DCSetup' will copy and execute the script copied to the VM and'ScriptLoc' is the filepath to the script on the local machine. The other values are the same.

Manage-VirtualMachines -VMType DC -DCSetup -ScriptLoc 'Actual filepath to PowerShell script' -File 'Actual filepath of CSV being used'

** MORE TO COME

# NOTE 


I do not have a list of references I used to make this, but I appreciate all the random internet help I got to build this tool. Feel free to email me if you have questions: ryancatactual at gmail dot com

Constructive critcism is always welcome, but be gentle; I'm a delicate flower...
