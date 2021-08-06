{******************************************************************************
 *  sched.pp
 * 
 *  Gestionnaire de tache de DelphineOS
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0.3 - 24/07/2002 -  GaLi  - Modification du scheduler
 *
 *  version 0.0.2 - 25/06/2002 -  GaLi  - Suppression des procédures de gestion
 *                                        des processus pour les mettre dans
 *                                        process.pp
 *
 *  version 0.0.1 - 25/04/2002 - Bubule - Modification de la gestion du timer
 *                                        et du scheduler
 *
 *  version 0.0.0 - ??/01/2002 -  GaLi  - Version initiale
 *
 *  TODO : tous le reste
 *
 *  Je voudrais remercier Frank Cornelis qui developpe EduOS car il m'a permis
 *  de faire une commutation de tache qui fonctionne (apres toute une nuit de
 *  codage inutile !!!) : voir start.S
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit sched;


INTERFACE


{DEFINE DEBUG}


{$I fs.inc}
{$I process.inc}
{$I sched.inc}
{$I time.inc}


{ Procédures externes }

procedure farjump (tss : word ; ofs : pointer); external;
procedure printk (format : string ; args : array of const); external;
procedure set_intr_gate (n : dword ; addr : pointer); external;
procedure enable_IRQ (irq : byte); external;
procedure outb (port : word ; val : byte); external;
procedure initialise_compteur; external;


{ Variables externes }

var
   current    : P_task_struct; external name 'U_PROCESS_CURRENT';
   compteur   : dword; external name 'U_TIME_COMPTEUR';



IMPLEMENTATION



{******************************************************************************
 * schedule
 *
 * Gestionnaire des taches. Donne le contrôle à la tache suivante.
 *
 * REMARQUE : cette procédure doit être appelée avec les interruptions
 *            désactivées.
 *****************************************************************************}
procedure schedule; [public, alias : 'SCHEDULE'];

var
   old_current : P_task_struct;

begin

   { On va lancer le prochain processus dans la liste de ceux qui sont prêts }

   old_current := current;
   current     := current^.next_run;

   { Si le prochain est 'init', alors on lance encore le prochain }
   if (current^.pid = 1) then
       current := current^.next_run;

   if (current <> old_current) then
       begin
{$IFDEF DEBUG}
   printk('prev TR=%h4  CR3: %h  PID: %h4  ticks: %d\n', [old_current^.tss_entry, old_current^.tss^.cr3, old_current^.pid, old_current^.ticks]);
   printk('ESP0: %h  ESP3: %h  EBP: %h\n', [old_current^.tss^.esp0, old_current^.tss^.esp, old_current^.tss^.ebp]);
   
   printk('next TR=%h4  CR3: %h  PID: %h4  ticks: %d\n', [current^.tss_entry, current^.tss^.cr3, current^.pid, current^.ticks]);
   printk('ESP0: %h  ESP3: %h  EBP: %h\n', [current^.tss^.esp0, current^.tss^.esp, current^.tss^.ebp]);
{$ENDIF}

{printk('S(%d(%h)->%d(%h)) ', [old_current^.pid, old_current^.tss^.esp, current^.pid, current^.tss^.esp]);}

          farjump(current^.tss_entry, NIL);
       end;
end;



{******************************************************************************
 * timer_intr
 *
 * Activée uniquement par l'IRQ 0. Permet d'obtenir une valeur de "compteur"
 * valide et d'activer le scheduler à intervalles réguliers.
 *
 * REMARQUE: Les interruptions sont automatiquement coupées.
 *****************************************************************************}
procedure timer_intr; interrupt;

begin

   asm
      mov   al , $20
      out   $20, al
   end;

   { Incrémente le compteur système }
   compteur := compteur + INTERVAL;
   current^.ticks += 1;  { Mise à jour du temps CPU utilisé par le processus }

   { On lance le scheduler à intervalles réguliers }
   if ((compteur mod 200) = 0) or (current^.pid = 1) then 
       schedule;
end;



{******************************************************************************
 * init_sched
 *
 * Initialise le scheduler
 * Appelée uniquement à l'initialisation de DelphineOS
 *****************************************************************************}
procedure init_sched; [public, alias : 'INIT_SCHED'];

begin

   {* On va reprogrammer le PIT pour qu'il déclenche une interruption toutes
    * les 10ms (environ) *}

   initialise_compteur;

   set_intr_gate(32, @timer_intr);
   enable_IRQ(0);

end;



begin
end.
