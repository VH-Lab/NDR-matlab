function tf = isBlosc(bytesIn)
% ndr.format.blosc.isBlosc - true iff BYTESIN looks like a Blosc v1 container.
%
%   TF = ndr.format.blosc.isBlosc(BYTESIN)
%
%   Peeks at the first 16 bytes of BYTESIN and returns true when the
%   header is well-formed enough for ndr.format.blosc.decode to attempt
%   decompression. Blosc v1 does not use a fixed magic number, so this is
%   an informed heuristic rather than a full validation: it checks that
%   the header version byte is 1 or 2 and that cbytes (bytes 13..16)
%   matches the buffer length.
%
%   BYTESIN accepts any type; anything not already uint8 is typecast.
%
%   See also: ndr.format.blosc.header, ndr.format.blosc.decode.

    tf = false;
    if ~isa(bytesIn, 'uint8')
        try
            bytesIn = typecast(bytesIn(:), 'uint8');
        catch
            return;
        end
    end
    bytesIn = bytesIn(:);
    if numel(bytesIn) < 16
        return;
    end
    version = double(bytesIn(1));
    if version < 1 || version > 2
        return;
    end
    cbytes = double(typecast(bytesIn(13:16), 'uint32'));
    tf = (cbytes == numel(bytesIn));
end
