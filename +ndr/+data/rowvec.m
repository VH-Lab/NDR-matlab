function y = rowvec(x)
% ROWVEC - return a matrix reshaped as a row vector
%
%  Y = ndr.data.rowvec(X)
%
%  Returns the contents of the matrix X as a row vector Y that is Mx1,
%  where M is the product of all the sizes of the dimensions of X
%  (M = PROD(SIZE(X))).
% 
%  ndr.data.rowvec is equivalent to Y = X(:)';
%
%  This function is useful for addressing all of the elements of a matrix
%  as a vector when X is a subset of another matrix.
%
%  See also: ndr.data.colvec
%
%  Example: 
%    A = rand(5,5)
%    Y = ndr.data.rowvec(A(1:3,1:2)) % returns points in rows 1:3, columns 1:2
%

y = x(:)';
