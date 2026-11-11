"""Checkpoint permission never bypasses source integrity or unregistered tasks."""
import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from audit_project import acceptance_complete

class AcceptanceGateTests(unittest.TestCase):
 def summary(self,**changes):
  result={'acceptance_items':2,'open_acceptance_items':1,'status':'development_checkpoint','pending_acceptance':['Playthrough pending']}
  result.update(changes)
  return result
 def test_complete(self):
  self.assertTrue(acceptance_complete('- [x] A\n- [x] B',self.summary(open_acceptance_items=0,pending_acceptance=[]),False))
 def test_strict_rejects_pending(self):
  with self.assertRaises(AssertionError):acceptance_complete('- [x] A\n- [ ] Playthrough pending',self.summary())
 def test_registered_checkpoint(self):
  self.assertFalse(acceptance_complete('- [x] A\n- [ ] Playthrough pending',self.summary(),True))
 def test_no_checkpoint_status(self):
  with self.assertRaises(AssertionError):acceptance_complete('- [x] A\n- [ ] Playthrough pending',self.summary(status='complete'),True)
 def test_unregistered_task(self):
  with self.assertRaises(AssertionError):acceptance_complete('- [x] A\n- [ ] Other failure',self.summary(),True)
 def test_wrong_counts(self):
  for changes in [{'acceptance_items':9},{'open_acceptance_items':0}]:
   with self.assertRaises(AssertionError):acceptance_complete('- [x] A\n- [ ] Playthrough pending',self.summary(**changes),True)
if __name__=='__main__':unittest.main()
