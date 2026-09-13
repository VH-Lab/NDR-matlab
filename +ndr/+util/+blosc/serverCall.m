function payload = serverCall(op, optionsSlug, requestBody)
% ndr.util.blosc.serverCall - one request to the persistent blosc server
%
%   PAYLOAD = ndr.util.blosc.SERVERCALL(OP, OPTIONSSLUG, REQUESTBODY)
%
%   OP           - 4-char verb: 'ENCB', 'DECB', 'QUIT'.
%   OPTIONSSLUG  - up to 32 chars of key=val,key=val options
%                  (ignored on DECB and QUIT); right-padded to 32.
%   REQUESTBODY  - uint8 vector, the batched-request body: a 4-byte
%                  little-endian count then N items each prefixed by
%                  an 8-byte little-endian length.
%
%   Returns the response PAYLOAD as a uint8 column vector on success,
%   or raises with the error text on an ERR response.
%
%   Wire format is defined by blosc_tool.py's `server` verb -- see
%   its docstring. Blocking single-request-at-a-time; the caller
%   expects the server to be idle before this returns.

    if nargin < 2, optionsSlug = ''; end
    if nargin < 3, requestBody = uint8([]); end
    if ~isa(requestBody, 'uint8')
        requestBody = typecast(requestBody(:), 'uint8');
    end
    requestBody = requestBody(:);

    op = char(op);
    if numel(op) ~= 4
        error('ndr:util:blosc:serverCall:BadOp', ...
            'op must be exactly 4 characters, got %d.', numel(op));
    end
    optionsSlug = char(optionsSlug);
    if numel(optionsSlug) > 32
        error('ndr:util:blosc:serverCall:BadOptions', ...
            'options slug is %d chars, max 32.', numel(optionsSlug));
    end
    optsBuf = zeros(1, 32, 'uint8');
    optsBuf(1:numel(optionsSlug)) = uint8(optionsSlug);

    h = ndr.util.blosc.serverConnect();

    % Header: 4 bytes op | 32 bytes options | 8 bytes payload length
    header = [uint8(op(:))'  optsBuf  ...
              typecast(uint64(numel(requestBody)), 'uint8')'];
    header = int8(typecast(header, 'int8'));
    h.in.write(header, 0, numel(header));
    if ~isempty(requestBody)
        body = typecast(requestBody, 'int8');
        h.in.write(body, 0, numel(body));
    end
    h.in.flush();

    % Response: 4 bytes status | 8 bytes length | body
    statusBytes = readExact(h.out, 4);
    lenBytes    = readExact(h.out, 8);
    payloadLen  = typecast(lenBytes, 'uint64');
    body        = readExact(h.out, double(payloadLen));

    status = char(statusBytes(:)');
    if strncmp(status, 'ERR', 3)
        msg = char(body(:)');
        error('ndr:util:blosc:serverCall:ToolFailed', ...
            'blosc_tool server refused %s: %s', op, msg);
    elseif ~strncmp(status, 'OK', 2)
        error('ndr:util:blosc:serverCall:BadStatus', ...
            'blosc_tool server returned unknown status "%s".', status);
    end
    payload = body(:);
end

function bytes = readExact(dataInputStream, n)
% DataInputStream.readFully throws EOFException on premature EOF,
% which reaches MATLAB as a matlab.exception.JavaException; the
% caller's error path treats that as a broken server.
    if n == 0
        bytes = uint8(zeros(0, 1));
        return;
    end
    buf = int8(zeros(1, n));
    dataInputStream.readFully(buf);
    bytes = typecast(int8(buf(:)), 'uint8');
end
