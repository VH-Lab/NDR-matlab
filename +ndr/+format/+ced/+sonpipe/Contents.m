% +CED/+SONPIPE  MATLAB adapter for the sonpipe command-line bridge.
%
%   These functions let NDR read 64-bit CED Spike2 (.smrx, "son64") files by
%   shelling out to the standalone `sonpipe` command-line tool, which uses CED's
%   sonpy (GPLv3). NDR's ndr.format.ced.read_SOMSMR_* functions call into here
%   only for 64-bit files (see ndr.format.ced.isSON64); 32-bit files use the
%   built-in sigTOOL reader.
%
%   This is a SYNCED COPY of the MATLAB client in the sonpipe repository
%   (VH-Lab/sonpipe, matlab/+sonpipe). It is intentionally embedded so NDR's
%   MATLAB side is self-contained and does not depend on sonpipe's MATLAB
%   package being on the path.
%
%   IMPORTANT: do not edit these files here. Fix them in VH-Lab/sonpipe and
%   re-sync. Improvements to the sonpipe *engine* (the CLI, sonpy support, new
%   channel types) reach NDR automatically by updating the installed CLI; only
%   changes to the CLI's output contract require re-syncing this adapter.
%
%   The sonpipe command-line tool itself is a separate install (Python + sonpy);
%   run `ndr.setup.sonpipe` for guidance.
%
%   Functions:
%     read_SOMSMR_header          - read file + channel header via sonpipe
%     read_SOMSMR_sampleinterval  - sample interval / rate for one channel
%     read_SOMSMR_datafile        - read waveform, event, or marker data
%     channelinfo                 - look up one channel's header entry
%     executable                  - locate / set / query the sonpipe CLI command
%     runcmd                      - run a system command with a Python-safe env
%
%   See also: ndr.format.ced.isSON64, ndr.format.ced.read_SOMSMR_header,
%     ndr.setup.sonpipe
