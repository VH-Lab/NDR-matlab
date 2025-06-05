function b = python_detect()
% PYTHON_DETECT - detect if we have Python here
%
% B = PYTHON_DETECT()
%
% Run code to detect the presence of Python. If this Matlab application has
% Python on board, B is 1. Otherwise, B is 0.
%
% Note: This function may fail to compile on systems that lack Python. We
% recommend calling this function within a try/catch loop.
%

b = 0;
try
	P = py.sys.path;
	b = 1;
end


