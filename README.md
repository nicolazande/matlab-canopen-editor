# Matlab CANopen Editor
Matlab CANopen EDS file editor

## Overview
This application can be used to view, edit and create CANopen EDS (Electronic Data Sheet) files directly in Matlab.

## Installation
The application can be installed by double clicking the `CANopenEditor.mlappinstall` file in the top directory. The source code is included in the `sources` directory.

## Intial window
![init](https://github.com/nicolazande/matlab-canopen-editor/assets/115359494/a52df336-3dd3-4b2e-b1e4-556ed5901621)
The application design is minimal and allows the user to select ad existing EDS file or create a new one from file explorer.

## Home
![home](https://github.com/nicolazande/matlab-canopen-editor/assets/115359494/b9e06863-43c7-4688-bab0-6d208259a53b)
The home window shows the general EDS file information (vendor name, vendor id, date, number of PDOs, ...). The user can edit these information directly in the GUI.

## Object dictionary
![object_dictionary](https://github.com/nicolazande/matlab-canopen-editor/assets/115359494/0c42104f-a476-4611-b107-838c4779c202)
The second tab shows all object dictionary entries specified in the EDS file. The user can search for a specific entry using the configurations in the top panel and clicking the `Search` button, or can create new object dictionary entries with the same configurations and by clicking the `New` button.

## RPDO
![RPDO](https://github.com/nicolazande/matlab-canopen-editor/assets/115359494/5f0b57ae-cda6-4f1f-b9bb-db70830d5704)
The RPDO (receive process data object) tab shows the RPDO specified in the EDS file. The user can create new RPDOs by specifying an index (only in range 0x1400 - 0x15FF) and a COB-ID and by clicking the `New RPDO` button. Once a new RPDO is created, the user can specify both Communication and Mapping parameters. The available communication parameters for RPDOs are only COB-ID and transmission type. To map a new object dictionary entry to a RPDO click `ENTER` on an empty mapping record slot and select from the avaiable objects the desired one (always by clicking `ENTER` on the object slot). By clicking `ENTER` on a non empty RPDO slot the user can see the details of the mapped object. To delete a mapped object, select its slot in the mapping record and click `CANC`. To delete the whole record (communication or mapping), click on the first column of the record (where the number is shown) and click `CANC`.

## TPDO
![TPDO](https://github.com/nicolazande/matlab-canopen-editor/assets/115359494/fdccb0c3-bb85-4265-b771-33e283833e80)
The TPDO (transmit process data object) tab shows the TPDO specified in the EDS file. The logic is the same of the RPDO but the index range for the TPDOs is 0x1800 - 0x19FF.

## SRDO
![SRDO](https://github.com/nicolazande/matlab-canopen-editor/assets/115359494/d892a504-1f44-48a3-87bd-176c95f18c6b)
The SRDO (safety relevant data object) tab shows the SRDO specified in the EDS file. The logic is the same of the RPDOand TPDO but the index range for the TPDOs is 0x1301 - 0x1380. It is user responsability to properly map normal and byte inverted objects in the SRDOs in the proper order.

## Update file
![update](https://github.com/nicolazande/matlab-canopen-editor/assets/115359494/51f9282a-e8f0-4b9c-bd98-6bb50736f61f)
The user can save the modified EDS file by clicking the `Export EDS` button, selecting a destination directory and file name from the file explorer.
