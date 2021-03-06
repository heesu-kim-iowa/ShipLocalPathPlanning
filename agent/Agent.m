classdef Agent < handle
    
    properties
        model
        B = 2.5     % beam(m)
        L = 4.88    % length(m)
        radius = 2.44
        position
        velocity
        Rf
        Ra
        Rp
        Rs
        feasibleAcceleration
        reachableVelocities
        rpm_port = 2380
        rpm_stbd = 2380
        rpm_rate = 1510
        rpm_port_min
        rpm_port_max
        rpm_port_grid
        rpm_stbd_min
        rpm_stbd_max
        rpm_stbd_grid
        rpm_min_limit = -2380
        rpm_max_limit = 2380
        idx_tau_in_f_grid
        idx_rpm_in_T_grid
    end
    
    methods
        function feasible_acceleration(obj)
            %% Rpm range
            global dt
            obj.rpm_port_min = obj.rpm_port - obj.rpm_rate * dt ;
            obj.rpm_port_max = obj.rpm_port + obj.rpm_rate * dt ;
            
            obj.rpm_stbd_min = obj.rpm_stbd - obj.rpm_rate * dt ;
            obj.rpm_stbd_max = obj.rpm_stbd + obj.rpm_rate * dt ;
            
            %% Limit of rpm
            if obj.rpm_port_min < obj.rpm_min_limit
                obj.rpm_port_min = obj.rpm_min_limit ;
            end
            if obj.rpm_port_max > obj.rpm_max_limit
                obj.rpm_port_max = obj.rpm_max_limit ;
            end
            
            if obj.rpm_stbd_min < obj.rpm_min_limit
                obj.rpm_stbd_min = obj.rpm_min_limit ;
            end
            if obj.rpm_stbd_max > obj.rpm_max_limit
                obj.rpm_stbd_max = obj.rpm_max_limit ;
            end

            %% Rpm grid
            N_rpm_grid = 100 ;
            idx_rpm_port = 1:N_rpm_grid ;
            idx_rpm_stbd = 1:N_rpm_grid ;
            
            obj.rpm_port_grid = linspace(obj.rpm_port_min, obj.rpm_port_max, N_rpm_grid) ;
            obj.rpm_stbd_grid = linspace(obj.rpm_stbd_min, obj.rpm_stbd_max, N_rpm_grid) ;
            
            %% Thrust grid
            for i = 1:N_rpm_grid
                if obj.rpm_port_grid(i) < 0
                    T_port_grid(i) = -1.189e-5 * obj.rpm_port_grid(i)^2 + 0.071 * obj.rpm_port_grid(i) + 4.331 ;
                elseif obj.rpm_port_grid(i) >= 0
                    T_port_grid(i) = 3.54e-5 * obj.rpm_port_grid(i)^2 + 0.084 * obj.rpm_port_grid(i) - 3.798 ;  
                end
                if obj.rpm_stbd_grid(i) < 0
                    T_stbd_grid(i) = -1.189e-5 * obj.rpm_stbd_grid(i)^2 + 0.071 * obj.rpm_stbd_grid(i) + 4.331 ;
                elseif obj.rpm_stbd_grid(i) >= 0
                    T_stbd_grid(i) = 3.54e-5 * obj.rpm_stbd_grid(i)^2 + 0.084 * obj.rpm_stbd_grid(i) - 3.798 ;  
                end
            end

            %% Control force grid
            T_grid = combvec(T_port_grid, T_stbd_grid) ;
            obj.idx_rpm_in_T_grid = combvec(idx_rpm_port, idx_rpm_stbd) ;
            
            tau_x_grid = T_grid(1, :) + T_grid(2, :) ;
            tau_n_grid = (T_grid(1, :) - T_grid(2, :)) * obj.B / 2 ;
            
            %% Feasible acceleration
            f_grid = [tau_x_grid; tau_n_grid] ;
                        
            for i = 1:length(f_grid)
                obj.feasibleAcceleration(:, i) = obj.model.C_nu * obj.velocity + obj.model.C_tau * f_grid(:, i) ;
            end
        end
        
        function setNextPosition(obj)
            global dt
            move = obj.velocity * dt ;
            newPosition = obj.position + move ;
            obj.position(1) = newPosition(1) ;
            obj.position(2) = newPosition(2) ;
            obj.position(3) = atan2(obj.velocity(2), obj.velocity(1)) ;
        end
        
        function update_rpm(obj, idx)
            idx_rpm_port = obj.idx_rpm_in_T_grid(1, idx) ;
            idx_rpm_stbd = obj.idx_rpm_in_T_grid(2, idx) ;
            obj.rpm_port = obj.rpm_port_grid(idx_rpm_port) ;
            obj.rpm_stbd = obj.rpm_stbd_grid(idx_rpm_stbd) ;
        end
        
        function update_ship_domain(obj)
            vOwnMeterPerSec = sqrt(obj.velocity(1)^2 + obj.velocity(2)^2) ;
            vOwnKnot = 1.94384 * vOwnMeterPerSec ;
            
            kAD = 10 ^ (0.3591 * log10(vOwnKnot) + 0.0952) ;
            kDT = 10 ^ (0.5441 * log10(vOwnKnot) - 0.0795) ;
            
            % With Kijima ship domain model
            obj.Rf = (1 + 1.34 * sqrt(kAD^2 + (kDT/2)^2)) * obj.L ;
            obj.Ra = (1 + 0.67 * sqrt(kAD^2 + (kDT/2)^2)) * obj.L ;
            obj.Rp = (0.2 + 0.75 * kDT) * obj.L ;
            obj.Rs = (0.2 + kDT) * obj.L ;

            if obj.Rf < obj.L/2
                obj.Rf = obj.L/2 ;
            end
            if obj.Ra < obj.L/2
                obj.Ra = obj.L/2 ;
            end
            if obj.Rp < obj.B/2
                obj.Rp = obj.B/2 ;
            end
            if obj.Rs < obj.B/2
                obj.Rs = obj.B/2 ;
            end
            
            % Without any ship domain
%             obj.Rf = 0 ;
%             obj.Ra = 0 ;
%             obj.Rp = 0 ;
%             obj.Rs = 0 ;
        end
        
        function emergency_ship_domain(obj)
            obj.Rf = obj.L/2 ;
            obj.Ra = obj.L/2 ;
            obj.Rp = obj.B/2 ;
            obj.Rs = obj.B/2 ;
        end
        
    end
end

