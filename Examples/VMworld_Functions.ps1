<#
 VMworld 2016 NET7514 demo script
 Nick Bradford, nbradford@vmware.com
 The reason this script is structured the way it is is purely to aid in 
 demonstration of the individual commands in front of a large audience of people
 where my typing is not likely to be at its best! :)

 A global 'steps' array is defined that contains each of the commands as they 
 would be typed (minus the {} script block wrapper) by an operator doing each 
 step manually.

 ShowTheAwesome is the function that, when executed, shows the command being run
 on screen, and then executes it within the global scope (so variables can be 
 used without scope modifiers.)

 Anyone who is starting with PoSH/PowerNSX might not understand exactly what I 
 mean above, but suffice to say, if you copy each command within the {}'s and run 
 it, sequentially, you will get the same result.

#>

<#
Copyright © 2015 VMware, Inc. All Rights Reserved.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License version 2, as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTIBILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License version 2 for more details.

You should have received a copy of the General Public License version 2 along with this program.
If not, see https://www.gnu.org/licenses/gpl-2.0.html.

The full text of the General Public License 2.0 is provided in the COPYING file.
Some files may be comprised of various open source software components, each of which
has its own license that is located in the source code of the respective component.”
#>



$steps = @(
    {connect-nsxserver -server "nsx-m-01a-local.corp.local" -username admin -password VMware1! -viusername administrator@vsphere.local -vipassword VMware1! -ViWarningAction "Ignore"},
    {$tz = Get-NsxTransportZone },
    {$webls = New-NsxLogicalSwitch -TransportZone $tz -Name webls},
    {$appls = New-NsxLogicalSwitch -TransportZone $tz -Name appls},
    {$dbls = New-NsxLogicalSwitch -TransportZone $tz -Name dbls},
    {$transitls = New-NsxLogicalSwitch -TransportZone $tz -Name transitls},
    {$uplink = New-NsxEdgeInterfaceSpec -Index 0 -Name uplink -type uplink -ConnectedTo (Get-VDPortgroup internal) -PrimaryAddress 192.168.119.150 -SubnetPrefixLength 24},
    {$transit = New-NsxEdgeInterfaceSpec -Index 1 -Name transit -type internal -ConnectedTo (Get-nsxlogicalswitch transitls) -PrimaryAddress 172.16.1.1 -SubnetPrefixLength 29},
    {new-nsxedge -Name edge01 -Cluster (get-cluster mgmt01) -Datastore (get-datastore mgmtdata) -Password VMware1!VMware1! -FormFactor compact -Interface $uplink,$transit -FwDefaultPolicyAllow},
    {get-nsxedge edge01 | Get-NsxEdgeRouting | Set-NsxEdgeRouting -DefaultGatewayAddress 192.168.119.2 -confirm:$false},
    {get-nsxedge edge01 | Get-NsxEdgeRouting | Set-NsxEdgeRouting -EnableBgp -LocalAS 100 -RouterId 192.168.119.200 -confirm:$false},
    {get-nsxedge edge01 | Get-NsxEdgeRouting | Set-NsxEdgeBgp -DefaultOriginate -confirm:$false},
    {get-nsxedge edge01 | Get-NsxEdgeRouting | Set-NsxEdgeRouting -EnableBgpRouteRedistribution -confirm:$false},
    {get-nsxedge edge01 | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -IpAddress 172.16.1.3 -RemoteAS 200 -confirm:$false},
    {get-nsxedge edge01 | Get-NsxEdgeRouting | New-NsxEdgeRedistributionRule -Learner bgp -FromStatic -confirm:$false},
    {$uplinklif = New-NsxLogicalRouterInterfaceSpec -Name Uplink -Type uplink -ConnectedTo (Get-NsxLogicalSwitch transitls) -PrimaryAddress 172.16.1.2 -SubnetPrefixLength 29},
    {$weblif = New-NsxLogicalRouterInterfaceSpec -Name web -Type internal -ConnectedTo (Get-NsxLogicalSwitch webls) -PrimaryAddress 10.0.1.1 -SubnetPrefixLength 24},
    {$applif = New-NsxLogicalRouterInterfaceSpec -Name app -Type internal -ConnectedTo (Get-NsxLogicalSwitch appls) -PrimaryAddress 10.0.2.1 -SubnetPrefixLength 24},
    {$dblif = New-NsxLogicalRouterInterfaceSpec -Name db -Type internal -ConnectedTo (Get-NsxLogicalSwitch dbls) -PrimaryAddress 10.0.3.1 -SubnetPrefixLength 24},
    {New-NsxLogicalRouter -Name LogicalRouter01 -ManagementPortGroup (Get-VDPortgroup internal) -Interface $uplinklif,$weblif,$applif,$dblif -Cluster (get-cluster mgmt01) -Datastore (get-datastore mgmtdata)},
    {get-nsxlogicalrouter LogicalRouter01 | Get-NsxLogicalRouterRouting | Set-NsxLogicalRouterRouting -EnableBgp -ProtocolAddress 172.16.1.3 -ForwardingAddress 172.16.1.2 -LocalAS 200 -RouterId 172.16.1.3 -confirm:$false},
    {get-nsxlogicalrouter LogicalRouter01 | Get-NsxLogicalRouterRouting | Set-NsxLogicalRouterRouting -EnableBgpRouteRedistribution -confirm:$false},
    {Get-NsxLogicalRouter LogicalRouter01 | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterRedistributionRule -FromConnected -Learner bgp -confirm:$false},
    {Get-NsxLogicalRouter LogicalRouter01 | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterBgpNeighbour -IpAddress 172.16.1.1 -RemoteAS 100 -ForwardingAddress 172.16.1.2 -ProtocolAddress 172.16.1.3 -confirm:$false}
    {$webpg = $webls | Get-NsxBackingPortGroup},
    {$apppg = $appls | Get-NsxBackingPortGroup},
    {$dbpg = $dbls | Get-NsxBackingPortGroup},
    {get-vm | where { $_.name -match 'web'} | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $webpg -Confirm:$false},
    {get-vm | where { $_.name -match 'app'} | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $apppg -Confirm:$false},
    {get-vm | where { $_.name -match 'db'} | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $dbpg -Confirm:$false}
    

)

$cleanup = @(

    {Get-VApp | get-vm | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup Internal -Confirm:$false},
    {Get-NsxEdge | Remove-NsxEdge -Confirm:$false},
    {Get-NsxLogicalRouter | Remove-NsxLogicalRouter -Confirm:$false},
    {Get-NsxLogicalSwitch | Remove-NsxLogicalSwitch -Confirm:$false}
)


function ShowTheAwesome { 

    foreach ( $step in $steps ) { 

        #Show me first
        write-host -foregroundcolor yellow ">>> $step"

        write-host "Press a key to run the command..."
        #wait for a keypress to continue
        $junk = [console]::ReadKey($true)

        #execute (dot source) me in global scope
        . $step
    }
}

function CleanupTheAwesome { 

    foreach ( $step in $cleanup ) { 

        #Show me first
        write-host -foregroundcolor yellow ">>> $step"

        write-host "Press a key to run the command..."
        #wait for a keypress to continue
        $junk = [console]::ReadKey($true)

        #execute (dot source) me in global scope
        . $step
    }
}