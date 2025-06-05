function reqBitDepth = bitDepth(numberLevels)
%BITDEPTH Calculate required standard bit depth for a number of levels.
%   reqBitDepth = BITDEPTH(numberLevels) calculates the minimum number of
%   bits required to represent 'numberLevels' distinct values, and then
%   rounds this value up to the nearest standard bit depth from the set
%   {4, 8, 16, 32, 64, 128, 256}.
%
%   Syntax:
%       reqBitDepth = bitDepth(numberLevels)
%
%   Description:
%       The function determines the smallest integer 'b' such that 2^b is
%       greater than or equal to numberLevels. This theoretical minimum 'b'
%       is calculated as ceil(log2(numberLevels)). The function then finds
%       the smallest value in the predefined list of standard bit depths
%       [4, 8, 16, 32, 64, 128, 256] that is greater than or equal to 'b'.
%       If the number of levels requires more than 256 bits, the function
%       will produce an error. Note that representing 1 level requires a
%       minimum of 0 bits theoretically, but this function returns the
%       smallest standard size, which is 4.
%
%   Input Arguments:
%       numberLevels - The number of distinct levels or values that need to
%                      be represented.
%                      Type: numeric scalar
%                      Constraints: Must be a positive integer (>= 1).
%
%   Output Arguments:
%       reqBitDepth - The required bit depth, rounded up to the nearest
%                     standard size.
%                     Type: numeric scalar
%                     Value: Will be one of 4, 8, 16, 32, 64, 128, or 256.
%
%   Examples:
%       % How many bits to represent 100 different intensity levels?
%       b = bitDepth(100)
%       % ceil(log2(100)) is 7. Round up standard size is 8.
%       % Expected output: b = 8
%
%       % How many bits for a typical 8-bit grayscale image range?
%       b = bitDepth(256)
%       % ceil(log2(256)) is 8. Round up standard size is 8.
%       % Expected output: b = 8
%
%       % How many bits if you need just one more level than 8-bit?
%       b = bitDepth(257)
%       % ceil(log2(257)) is 9. Round up standard size is 16.
%       % Expected output: b = 16
%
%       % How many bits needed for just 1 level? (Returns smallest standard size)
%       b = bitDepth(1)
%       % Expected output: b = 4
%
%       % How many bits needed for 2 levels?
%       b = bitDepth(2)
%       % ceil(log2(2)) is 1. Round up standard size is 4.
%       % Expected output: b = 4
%
%       % How many bits for exactly 16 levels?
%       b = bitDepth(16)
%       % ceil(log2(16)) is 4. Round up standard size is 4.
%       % Expected output: b = 4
%
%       % How many bits for 17 levels?
%       b = bitDepth(17)
%       % ceil(log2(17)) is 5. Round up standard size is 8.
%       % Expected output: b = 8
%
%       % Example that would error (requires > 256 bits)
%       try
%           hugeNumLevels = pow2(256) + 1; % Needs 257 bits
%           b = bitDepth(hugeNumLevels)
%       catch ME
%           disp(ME.message)
%           fprintf('Error ID: %s\n', ME.identifier);
%       end
%       % Expected output: Error message "Number of levels (...) requires
%       %                  more than 256 bits."
%       %                  Error ID: bitDepth:LevelsTooHigh
%
%   See also: log2, ceil, find, pow2, arguments

% --- Input Argument Validation ---
arguments
    numberLevels (1,1) {mustBeNumeric, mustBePositive, mustBeInteger}
    % numberLevels must be a single (scalar), positive, integer value.
end

% --- Define Standard Bit Depths ---
standardDepths = [4, 8, 16, 32, 64, 128, 256];

% --- Function Logic ---

% Handle the edge case of 1 level separately, as log2(1) = 0.
% The smallest standard bit depth is 4.
if numberLevels == 1
    minBits = 0; % Theoretical minimum bits
    reqBitDepth = standardDepths(1); % Smallest standard size
else
    % Calculate the theoretical minimum number of bits required
    minBits = ceil(log2(numberLevels));

    % Find the index of the first standard bit depth that meets the requirement
    idx = find(standardDepths >= minBits, 1, 'first');

    % Check if a suitable standard depth was found within the list
    if isempty(idx)
        % This occurs if minBits > standardDepths(end)
        error('bitDepth:LevelsTooHigh', ...
              'Number of levels (%d) requires more than %d bits.', ...
              numberLevels, standardDepths(end));
    else
        % Assign the found standard bit depth
        reqBitDepth = standardDepths(idx);
    end
end

end % function bitDepth

