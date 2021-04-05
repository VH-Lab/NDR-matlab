classdef clocktype
% CLOCKTYPE - a class for specifying a clock type in the NDR framework
%
%
	properties (SetAccess=protected, GetAccess=public)
		type % the ndr_clock type; in this class, acceptable values are 'UTC', 'exp_global_time', and 'no_time'
	end

	methods
		function obj = clocktype(type)
			% ndr.time.clocktype - Creates a new ndr.time.clocktype object
			%
			% OBJ = ndr.time.clocktype(TYPE)
			%
			% Creates a new ndr.time.clocktype object. TYPE can be
			% any of the following strings (with description):
			%
			% TYPE string               | Description
			% ------------------------------------------------------------------------------
			% 'utc'                     | Universal coordinated time (within 0.1ms)
			% 'approx_utc'              | Universal coordinated time (within 5 seconds)
			% 'exp_global_time'         | Experiment global time (within 0.1ms)
			% 'approx_exp_global_time'  | Experiment global time (within 5s)
			% 'dev_global_time'         | A device keeps its own global time (within 0.1ms) 
			%                           |   (that is, it knows its own clock across recording epochs)
			% 'approx_dev_global_time'  |  A device keeps its own global time (within 5 s) 
			%                           |   (that is, it knows its own clock across recording epochs)
			% 'dev_local_time'          | A device keeps its own local time only within epochs
			% 'no_time'                 | No timing information
			% 'inherited'               | The timing information is inherited from another device.
			%
				obj.type = '';

				if nargin>0,
					obj = setclocktype(obj,type);
				end
		end % clocktype()
		
		function ndr_clocktype_obj = setclocktype(ndr_clocktype_obj, type)
			% SETCLOCKTYPE - Set the type of an ndr.time.clocktype
			%
			% NDR_CLOCKTYPE_OBJ = SETCLOCKTYPE(NDR_CLOCKTYPE_OBJ, TYPE)
			%
			% Sets the TYPE property of an ndr.time.clocktype object NDR_CLOCKTYPE_OBJ.
			% Valid values for the TYPE string are as follows:
			%
			% TYPE string               | Description
			% ------------------------------------------------------------------------------
			% 'utc'                     | Universal coordinated time (within 0.1ms)
			% 'approx_utc'              | Universal coordinated time (within 5 seconds)
			% 'exp_global_time'         | Experiment global time (within 0.1ms)
			% 'approx_exp_global_time'  | Experiment global time (within 5s)
			% 'dev_global_time'         | A device keeps its own global time (within 0.1ms) 
			%                           |   (that is, it knows its own clock across recording epochs)
			% 'approx_dev_global_time'  |  A device keeps its own global time (within 5 s) 
			%                           |   (that is, it knows its own clock across recording epochs)
			% 'dev_local_time'          | A device keeps its own local time only within epochs
			% 'no_time'                 | No timing information
			% 'inherited'               | The timing information is inherited from another device.
			%
			%
				if ~ischar(type),
					error(['TYPE must be a character string.']);
				end

				type = lower(type);

				switch type,
					case {'utc','approx_utc','exp_global_time','approx_exp_global_time',...
						'dev_global_time', 'approx_dev_global_time', 'dev_local_time', ...
						'no_time','inherited'},
						% no error
					otherwise,
						error(['Unknown clock type ' type '.']);
				end

				ndr_clocktype_obj.type = type;
		end % setclocktype() %

		function b = needsepoch(ndr_clocktype_obj)
			% NEEDSEPOCH - does this clocktype need an epoch for full description?
			%
			% B = NEEDSEPOCH(NDR_CLOCKTYPE_OBJ)
			%
			% Does this ndr.time.clocktype object need an epoch in order to specify time?
			%
			% Returns 1 for 'dev_local_time', 0 otherwise.
			%
				b = strcmp(ndr_clocktype_obj,'dev_local_time');
		end % needsepoch

		function str = ndr_clocktype2char(ndr_clocktype_obj)
			% NDR_CLOCKTYPE2CHAR - produce the NDR_CLOCKTOP's type as a string
			%
			% STR = NDR_CLOCKTYPE2CHAR(NDR_CLOCKTYPE_OBJ)
			%
			% Return a string STR equal to the ndr.time.clocktype object's type parameter.
			%
				str = ndr_clocktype_obj.type;
		end % ndr_clocktype2char()

		function b = eq(ndr_clocktype_obj_a, ndr_clocktype_obj_b)
			% EQ - are two ndr.time.clocktype objects equal?
			%
			% B = EQ(NDS_CLOCK_OBJ_A, NDR_CLOCKTYPE_OBJ_B)
			%
			% Compares two NDR_CLOCKTYPE_objects and returns 1 if they refer to the 
			% same clock type.
			%
			b = strcmp(ndr_clocktype_obj_a.type,ndr_clocktype_obj_b.type);
		end % eq()

		function b = ne(ndr_clocktype_obj_a, ndr_cock_obj_b)
			% NE - are two ndr.time.clocktype objects not equal?
			%
			% B = EQ(NDS_CLOCK_OBJ_A, NDR_CLOCKTYPE_OBJ_B)
			%
			% Compares two NDR_CLOCKTYPE_objects and returns 0 if they refer to the 
			% same clock type.
			%
			b = ~eq(ndr_clocktype_obj_a.type,ndr_clocktype_obj_b.type);
		end % ne()

	end % methods
end % ndr.time.clocktype class
