<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

$host="dats05-dbproxy";
$db="student_grades";
$user="dats05";
$pw="however data Denmark";
$dbconn = new mysqli($host, $user, $pw, $db);
if($dbconn->connect_errno){
echo "FAIL";
}
echo $dbconn->host_info;

$sql = "SELECT s.name, g.subject, g.grade FROM students s,
grades g where s.studentid=g.studentid";
$result = $dbconn->query($sql);
echo "Student grades:<br />";
echo "<table border='1'>";
echo "<tr><td>Student name</td><td>Subject</td><td>Grade</td></tr>";
while ($row = $result->fetch_assoc()) {
echo "<tr><td>{$row['name']}</td> <td>{$row['subject']}</td><td>
{$row['grade']}</td></tr>";
}
echo "</table>";
$result->close();
$dbconn->close();
?>
