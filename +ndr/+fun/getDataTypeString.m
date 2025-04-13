function typeString = getDataTypeString(isSigned, isInt, bitDepth)
%GETDATATYPESTRING Returns a data type string based on properties.
%   typeString = GETDATATYPESTRING(isSigned, isInt, bitDepth) generates a
%   data type string (e.g., 'uint16', 'int32', 'float32', 'float64')
%   based on the specified properties.
%
%   Syntax:
%       typeString = getDataTypeString(isSigned, isInt, bitDepth)
%
%   Description:
%       This function determines a descriptive data type name given
%       whether the type is signed, whether it's an integer, and its bit
%       depth.
%       - For integers (isInt = true), it returns 'intX' or 'uintX' where X
%         is the bitDepth (8, 16, 32, or 64). These match standard MATLAB
%         integer type names.
%       - For floating-point numbers (isInt = false), it returns 'float32'
%         for bitDepth 32 or 'float64' for bitDepth 64. Note that these
%         ('float32', 'float64') are descriptive strings returned by this
%         function and correspond to MATLAB's standard 'single' and 'double'
%         types, respectively. The isSigned input is ignored for
%         floating-point types as standard floats (IEEE 754) are inherently
%         signed. Bit depths 8 and 16 are not valid for standard floats
%         and will cause an error if isInt is false.
%
%   Input Arguments:
%       isSigned - Specifies whether the data type is signed.
%                  Type: logical scalar (true or false)
%                  true: Signed type (e.g., int8, int32)
%                  false: Unsigned type (e.g., uint8, uint32). Ignored if
%                         isInt is false.
%
%       isInt    - Specifies whether the data type is an integer.
%                  Type: logical scalar (true or false)
%                  true: Integer type (int/uint)
%                  false: Floating-point type (float32/float64)
%
%       bitDepth - Specifies the number of bits for the data type.
%                  Type: numeric scalar
%                  Allowed values: 8, 16, 32, 64
%                  Must be a positive integer.
%
%   Output Arguments:
%       typeString - The data type name.
%                    Type: char row vector (e.g., 'int16', 'float64')
%
%   Examples:
%       % Get the type string for a signed 16-bit integer
%       str16 = getDataTypeString(true, true, 16)
%       % Expected output: str16 = 'int16'
%
%       % Get the type string for an unsigned 32-bit integer
%       strU32 = getDataTypeString(false, true, 32)
%       % Expected output: strU32 = 'uint32'
%
%       % Get the type string for a 32-bit floating-point number
%       % Note: isSigned input (true/false) doesn't change the result
%       strF32 = getDataTypeString(true, false, 32)
%       % Expected output: strF32 = 'float32'
%
%       % Get the type string for a 64-bit floating-point number
%       strF64 = getDataTypeString(false, false, 64)
%       % Expected output: strF64 = 'float64'
%
%       % Example of invalid input (float with 16 bits) - This will error
%       try
%           getDataTypeString(true, false, 16)
%       catch ME
%           disp(ME.message) % Display the error message
%           fprintf('Error ID: %s\n', ME.identifier); % Display error ID
%       end
%       % Expected output: Error message indicating invalid bit depth for float.
%       %                  Error ID: getDataTypeString:InvalidFloatBitDepth
%
%   See also: class, isa, int8, uint16, single, double, arguments, sprintf, error

% --- Input Argument Validation ---
arguments
    isSigned (1,1) logical % Must be a single logical value (true/false)
    isInt    (1,1) logical % Must be a single logical value (true/false)
    bitDepth (1,1) {mustBeNumeric, mustBePositive, mustBeInteger, mustBeMember(bitDepth, [8, 16, 32, 64])}
    % bitDepth must be a single number, positive, integer, and one of 8, 16, 32, 64
end

% --- Function Logic ---
if isInt
    % Integer type
    if isSigned
        prefix = 'int';
    else
        prefix = 'uint';
    end
    % Combine prefix and bit depth
    typeString = sprintf('%s%d', prefix, bitDepth);
else
    % Floating-point type
    % Check for valid bit depths for floats (32/64)
    if bitDepth == 32
        typeString = 'float32'; % Changed from 'single'
    elseif bitDepth == 64
        typeString = 'float64'; % Changed from 'double'
    else
        % This case handles bitDepth 8 or 16 when isInt is false.
        error('getDataTypeString:InvalidFloatBitDepth', ...
              'Floating-point types require 32-bit (''float32'') or 64-bit (''float64'') depths. Requested: %d bits.', bitDepth);
        % Note: The isSigned argument is ignored for float types, as
        % standard IEEE 754 floats are inherently signed.
    end
end

end % function getDataTypeString
