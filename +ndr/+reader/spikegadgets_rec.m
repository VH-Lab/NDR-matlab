classdef SpikeGadgetsReader < format.SpikeGadget.reader

% path --> epoch start&end 


	methods
  	  	function ndr_obj = SpikeGadgetsReader(ndr_SpikeGadgets) % input = filename(?)
		% READER - create a new Neuroscience Data Reader object
		%
		% READER_OBJ = ndr.ndr.reader()
		%
		% Creates an Neuroscence Data Reader object of SpikeGadgets.
			
        ndr_obj = format.SpikeGadget.reader(ndr_SpikeGadgets);

		end; % READER()
        
        % extract times, spikes

		function ec = epochclock(ndr_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - returns the types of time units available to this epoch of data
			
			% read header (?)
			

		end; % epochclock()
