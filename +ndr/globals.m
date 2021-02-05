% GLOBALS - define global variables for NDR
%
% NDR.GLOBALS
%  
% Script that defines some global variables for the NDR package
%
% The following variables are defined:
% 
% Name:                          | Description
% -------------------------------------------------------------------------
% ndr_globals.path.path          | The path of the NDR distribution on this machine.
%                                |   (Initialized by ndr_Init.m)
% ndr_globals.path.preferences   | A path to a directory of preferences files
% ndr_globals.path.filecachepath | A path where files may be cached (not deleted every time)
% ndr_globals.path.temppath      | The path to a directory that may be used for
%                                |   temporary files (Initialized by ndr_Init.m)
% ndi_globals.path.testpath      | A path to a safe place to run test code
% ndi.debug                      | A structure with preferences for debugging
%

global ndr_globals

