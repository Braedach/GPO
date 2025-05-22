# GPO via Microsoft Live reponse in MDE

Purpose is to allow for the Local GPO to be updated via Live Response
This is a manual affair for each computer but does not require physical assess

Assumptions:

1.  Computer is on and available in Live Response
2.  Files can be downloaded from this Github
3.  Files will automatically overwrite but registry.pol needs to be updated on changes
4.  The Sysinternals directory should be in existance on the endpoint but created it if it is not
5.  Another script is responsible for updating the SysInternals system to enhance MDE

Shortcomings

1.  A single registry.pol file is used which applies to the computer not the user
2.  I see no reason to change this
3.  File is in the public domain but okay with this for the time being


Fixed

1.  Fixed all the coding errors - my bad
2.  Tested on a purged system via local execution and Live response
3.  All policies have been updated and reflected in Microsoft Security Portal


Outstanding

1.  May have to look at the registry and see what needs to be adjusted based on the old implementation method

