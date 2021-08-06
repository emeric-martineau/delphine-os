const
   TASK_RUNNING         = 1;
   { Le processus est en cours d'execution soit en attente d'execution }

   TASK_INTERRUPTIBLE   = 2;
   { Le processus est suspendu (endormi) en attendant qu'une condition soit
     realisee. Le declenchement d'une interruption materielle, la liberation
     d'une ressource que le processus attend, la reception d'un signal sont
     autant d'exemple de conditions qui peuvent reveiller le processus, i.e.
     remettre son etat a la valeur TASK_RUNNING }

   TASK_UNINTERRUPTIBLE = 3;
   { Comme l'etat precedent, si ce n'est que l'envoi d'un signal au processus
     endormi ne change pas son etat. Cet etat est rarement utilise. }

   TASK_STOPPED         = 4;
   { L'execution du processus a ete arrete : le processus entre dans cet etat
     apres avoir recu un signal SIGSTOP, SIGTSTP, SIGTTIN ou SIGTTOU. }

   TASK_ZOMBIE          = 5;
   { L'execution du processus est terminee, mais son pere n'a pas encore
     utilise un appel systeme de type wait() pour obtenir des informations
     a propos du processus mort. Tant que l'appel systeme de type wait() n'a
     pas ete invoque, le noyau ne peut detruire les donnees contenues dans
     le descripteur du processus mort puisque le pere peut en avoir besoin. }
